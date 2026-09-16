import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/hardware/capture_button_channel.dart';
import '../../../../core/hardware/lens_info_channel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/entities/capture_quality.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../cubit/capture_session_cubit.dart';
import '../cubit/capture_session_state.dart';
import '../widgets/camera_grid_navigator.dart';
import '../widgets/grid_capture_metrics.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/quality_badge.dart';

class CameraCapturePage extends StatelessWidget {
  const CameraCapturePage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  @override
  Widget build(BuildContext context) {
    final initialCell =
        int.tryParse(
          GoRouterState.of(context).uri.queryParameters['cell'] ?? '',
        ) ??
        0;

    return BlocProvider(
      create: (_) =>
          CaptureSessionCubit(
              GetIt.instance<GridCaptureRepository>(),
              GetIt.instance<GridCaptureLocalDataSource>(),
            )
            ..init(floorId, wallId)
            ..openCell(initialCell),
      child: Scaffold(
        backgroundColor: AppColors.cameraBackground,
        body: SafeArea(
          child: BlocBuilder<CaptureSessionCubit, CaptureSessionState>(
            builder: (context, state) => switch (state) {
              CaptureSessionLoading() => const LoadingIndicator(),
              CaptureSessionError(:final message) => ErrorRetryView(
                message: message,
                onRetry: () =>
                    context.read<CaptureSessionCubit>().init(floorId, wallId),
              ),
              CaptureSessionNotFound() => EmptyState(
                icon: Icons.search_off,
                message: 'This wall could not be found.',
                actionLabel: 'Back',
                onAction: () => context.safePop(),
              ),
              CaptureSessionLoaded(grid: null) => const EmptyState(
                icon: Icons.grid_view,
                message: 'No grid set up yet for this wall.',
              ),
              CaptureSessionLoaded() => _CameraBody(
                state: state,
                siteId: siteId,
                buildingId: buildingId,
                floorId: floorId,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _CameraBody extends StatefulWidget {
  const _CameraBody({
    required this.state,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
  });

  final CaptureSessionLoaded state;
  final String siteId;
  final String buildingId;
  final String floorId;

  @override
  State<_CameraBody> createState() => _CameraBodyState();
}

enum _CameraLoadState { loading, ready, error }

class _CameraBodyState extends State<_CameraBody> {
  CameraController? _controller;
  _CameraLoadState _loadState = _CameraLoadState.loading;
  String? _errorMessage;
  bool _capturing = false;
  final Set<String> _deletingPaths = {};
  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _currentZoom = 1;
  double _appliedZoom = 1;
  double _baseZoom = 1;
  double? _pendingZoom;
  bool _applyingZoom = false;

  // When on, a successful capture automatically opens the next cell instead
  // of leaving the operator on the current one — see `_advanceToNextCell`.
  // Toggled by tapping the skip-next button rather than that button directly
  // advancing the cell.
  bool _autoAdvance = false;

  // Guards against overlapping camera-controller operations — e.g. tapping
  // a zoom preset mid-capture, or firing the shutter mid-lens-switch — which
  // is what let a `setZoomLevel`/`takePicture` call race a concurrent
  // `dispose()` on the same native session and crash on iOS (AVFoundation
  // has no protection against a platform call landing on a session that's
  // being torn down at the same moment).
  bool _switchingLens = false;

  // Set synchronously at the top of `dispose()` (before `mounted` flips
  // false) so an in-flight async method's next `await` sees it immediately
  // and stops issuing further native calls against a controller this widget
  // is in the middle of tearing down.
  bool _disposed = false;

  // The primary lens's own range, cached once at startup — used to decide
  // which zoom presets to show regardless of which physical lens is
  // currently active (switching to the ultra-wide lens temporarily reports
  // its own native ~1x-3x range, which must not hide the 1x/2x presets).
  double _primaryMinimumZoom = 1;
  double _primaryMaximumZoom = 1;
  List<CameraDescription> _backCameras = [];

  // Below 1x is optical, not digital: it requires physically switching to an
  // ultra-wide lens. Only set when the primary lens can't already reach
  // below 1x itself (e.g. iOS's fused virtual multi-camera device — see
  // third_party/camera_avfoundation — already covers that case without a
  // switch) and [LensInfoChannel] confirmed the device actually has a
  // distinct ultra-wide lens to switch to.
  CameraDescription? _ultraWideCamera;
  bool _onUltraWideLens = false;

  // The ultra-wide lens's zoom multiplier relative to the primary lens, as
  // reported by [LensInfoChannel] (e.g. 0.52 on a device whose "0.5x" lens
  // isn't exactly half). Falls back to the conventional 0.5 when unknown.
  double _ultraWideZoomRatio = 0.5;

  double get _displayZoom =>
      _onUltraWideLens ? _currentZoom * _ultraWideZoomRatio : _currentZoom;

  // True whenever 0.5x is actually reachable — either the primary lens
  // already natively zooms below 1x (no switch needed, e.g. iOS's fused
  // virtual multi-camera device), or there's a separate ultra-wide
  // CameraDescription to switch to.
  bool get _canReachUltraWide =>
      _ultraWideCamera != null ||
      _primaryMinimumZoom <= 0.5 + _ZoomPresets._matchTolerance;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    CaptureButtonChannel.listen(_handleShutter);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _loadState = _CameraLoadState.error;
          _errorMessage = 'No camera was found on this device.';
        });
        return;
      }
      final backCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();
      // Ask the platform which back lens is actually primary/ultra-wide —
      // see LensInfoChannel's doc for why guessing from list order/name
      // (the old approach) misidentifies lenses on several devices.
      final lensRoles = await LensInfoChannel.getBackLensRoles();
      final primaryCamera =
          _findCameraByName(backCameras, lensRoles?.primaryName) ??
          (backCameras.isNotEmpty ? backCameras.first : cameras.first);
      final ultraWideCamera = _findCameraByName(
        backCameras,
        lensRoles?.ultraWideName,
      );
      final controller = CameraController(
        primaryCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      final minimumZoom = await controller.getMinZoomLevel();
      final maximumZoom = await controller.getMaxZoomLevel();
      final initialZoom = 1.0.clamp(minimumZoom, maximumZoom).toDouble();
      await controller.setZoomLevel(initialZoom);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loadState = _CameraLoadState.ready;
        _backCameras = backCameras;
        _ultraWideCamera = ultraWideCamera;
        _ultraWideZoomRatio = lensRoles?.ultraWideZoomRatio ?? 0.5;
        _minimumZoom = minimumZoom;
        _maximumZoom = maximumZoom;
        _primaryMinimumZoom = minimumZoom;
        _primaryMaximumZoom = maximumZoom;
        _currentZoom = initialZoom;
        _appliedZoom = initialZoom;
        _baseZoom = initialZoom;
        _onUltraWideLens = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadState = _CameraLoadState.error;
        _errorMessage = error.toString();
      });
    }
  }

  static CameraDescription? _findCameraByName(
    List<CameraDescription> cameras,
    String? name,
  ) {
    if (name == null) return null;
    for (final camera in cameras) {
      if (camera.name == name) return camera;
    }
    return null;
  }

  /// Switches the live controller to a different physical back lens (e.g.
  /// primary <-> ultra-wide). The previous controller keeps rendering until
  /// the new one has initialized, so the viewfinder never has to fall back
  /// to a loading state mid-switch.
  Future<void> _switchLens(
    CameraDescription description, {
    required bool isUltraWide,
  }) async {
    // Re-entrancy guard: two overlapping switches (e.g. a double-tap across
    // presets before the first finishes initializing) would otherwise create
    // a second new controller while the first is still being wired up, and
    // both could end up racing to dispose the same previous controller.
    if (_switchingLens) return;
    _switchingLens = true;
    final previousController = _controller;
    try {
      final newController = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await newController.initialize();
      final minimumZoom = await newController.getMinZoomLevel();
      final maximumZoom = await newController.getMaxZoomLevel();
      await newController.setZoomLevel(minimumZoom);
      if (!mounted || _disposed) {
        await newController.dispose();
        return;
      }
      // A pinch/preset zoom requested just before this switch may still have
      // a `setZoomLevel` call in flight against `previousController` —
      // disposing it while that native call is still executing is what let
      // iOS crash (AVFoundation has no protection against a platform call
      // landing on a session that's being torn down at the same instant).
      while (_applyingZoom) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (!mounted || _disposed) {
        await newController.dispose();
        return;
      }
      setState(() {
        _controller = newController;
        _minimumZoom = minimumZoom;
        _maximumZoom = maximumZoom;
        _currentZoom = minimumZoom;
        _appliedZoom = minimumZoom;
        _baseZoom = minimumZoom;
        _onUltraWideLens = isUltraWide;
      });
      await previousController?.dispose();
    } on CameraException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not switch camera lens: '
              '${error.description ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      _switchingLens = false;
    }
  }

  Future<void> _handlePresetSelect(double level) async {
    if (_loadState != _CameraLoadState.ready || _capturing || _switchingLens) {
      return;
    }
    final wantsUltraWide = level < 1;
    if (wantsUltraWide && _ultraWideCamera != null) {
      if (!_onUltraWideLens) {
        await _switchLens(_ultraWideCamera!, isUltraWide: true);
      }
      return;
    }
    if (!wantsUltraWide && _onUltraWideLens) {
      await _switchLens(_backCameras.first, isUltraWide: false);
    }
    _requestZoom(level);
  }

  Future<void> _handleShutter() async {
    final controller = _controller;
    if (controller == null || _capturing || _switchingLens) return;
    setState(() => _capturing = true);
    try {
      // On iOS, the primary "camera" is often a virtual multi-lens device
      // (see third_party/camera_avfoundation's CameraPlugin.m fork) whose
      // zoom crosses physical lenses internally as `videoZoomFactor`
      // changes — capturing while that transition is still in flight (right
      // after a pinch/preset zoom) is a known source of intermittent
      // AVFoundation crashes on those devices, so wait for it to settle
      // first rather than firing the shutter concurrently with it.
      while (_applyingZoom) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (!mounted || _disposed) return;
      final file = await controller.takePicture();
      if (!mounted) return;
      await context.read<CaptureSessionCubit>().takePhoto(file);
      if (_autoAdvance) _advanceToNextCell();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _switchingLens || _capturing) return;
    _requestZoom(_baseZoom * details.scale);
  }

  void _requestZoom(double requestedZoom) {
    if (_loadState != _CameraLoadState.ready) return;
    final zoom = requestedZoom.clamp(_minimumZoom, _maximumZoom).toDouble();
    if ((zoom - _currentZoom).abs() < 0.01) return;

    setState(() => _currentZoom = zoom);
    _pendingZoom = zoom;
    if (!_applyingZoom) unawaited(_applyPendingZoom());
  }

  Future<void> _applyPendingZoom() async {
    _applyingZoom = true;
    try {
      while (mounted && !_disposed && _pendingZoom != null) {
        final zoom = _pendingZoom!;
        _pendingZoom = null;
        await _controller?.setZoomLevel(zoom);
        _appliedZoom = zoom;
      }
    } on CameraException catch (error) {
      _pendingZoom = null;
      if (mounted) {
        setState(() => _currentZoom = _appliedZoom);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not change camera zoom: '
              '${error.description ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      _applyingZoom = false;
      if (mounted && !_disposed && _pendingZoom != null) {
        unawaited(_applyPendingZoom());
      }
    }
  }

  Future<void> _handleDeletePhoto(int cellId, String path) async {
    if (_capturing || _switchingLens || _deletingPaths.contains(path)) return;
    setState(() => _deletingPaths.add(path));
    try {
      await context.read<CaptureSessionCubit>().deletePhoto(cellId, path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete the photo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingPaths.remove(path));
    }
  }

  /// Saves whatever's been captured so far straight to the wall's grid —
  /// [CaptureSessionCubit.savePartial] already marks the wall `captured` if
  /// every cell now has a photo, or `in_progress` otherwise, so one button
  /// covers both cases without the operator detouring through coverage
  /// review first.
  void _handleSave() {
    context.read<CaptureSessionCubit>().savePartial();
    // A single pop — not popToPath — back to GridCapturePage: this screen is
    // only ever reached by GridCapturePage's `_openCamera` pushing it, so
    // its immediate parent in the stack is always the wall's grid overview,
    // never the floor's wall list. `_openCamera` awaits this very push and
    // refreshes its own cubit once it resolves, so the grid overview picks
    // up this save without needing anything further here.
    context.safePop();
  }

  /// Advances the active cell to the next one in row-major order, once a
  /// capture has just landed on the current cell. Reads the cubit's own
  /// state rather than a value captured at build time, since it runs after
  /// `takePhoto`'s `await` — by then a newer state may already be current.
  /// A no-op past the last cell — there's nothing further to move to.
  void _advanceToNextCell() {
    final cubit = context.read<CaptureSessionCubit>();
    final current = cubit.state;
    if (current is! CaptureSessionLoaded || current.grid == null) return;
    final activeCellId = current.activeCellId ?? 0;
    final nextCellId = activeCellId + 1;
    if (nextCellId >= current.grid!.cells.length) return;
    cubit.openCell(nextCellId);
  }

  /// Toggles auto-advance mode: when on, a successful capture automatically
  /// opens the next cell instead of leaving the operator to switch manually.
  void _toggleAutoAdvance() {
    setState(() => _autoAdvance = !_autoAdvance);
  }

  @override
  void dispose() {
    // Set first, synchronously, so any in-flight async camera method's next
    // `await` sees it before this method disposes the controller out from
    // under it — see `_disposed`'s doc comment.
    _disposed = true;
    CaptureButtonChannel.stop();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.state.grid!;
    final rawActiveCellId = widget.state.activeCellId ?? 0;
    final activeCellId = rawActiveCellId < 0
        ? 0
        : (rawActiveCellId >= grid.cells.length
              ? grid.cells.length - 1
              : rawActiveCellId);
    final row = activeCellId ~/ grid.cols + 1;
    final col = activeCellId % grid.cols + 1;
    final cellLabel = 'R${row}C$col';
    final shotPaths = grid.cells[activeCellId].shotPaths;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Viewfinder(
                loadState: _loadState,
                errorMessage: _errorMessage,
                controller: _controller,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
              ),
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DarkPill(label: cellLabel),
                    const SizedBox(height: AppSpacing.xs),
                    QualityBadge(
                      result: widget.state.cellQuality[activeCellId],
                      analyzing: widget.state.analyzingCellIds.contains(activeCellId),
                      onToggleOverride: () => context
                          .read<CaptureSessionCubit>()
                          .toggleQualityOverride(activeCellId),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SaveButton(onTap: _capturing ? null : _handleSave),
                    const SizedBox(height: AppSpacing.sm),
                    _AutoAdvanceToggleButton(
                      enabled: _autoAdvance,
                      onTap: _toggleAutoAdvance,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: _RoundIconButton(
                    icon: Icons.arrow_back,
                    iconColor: Colors.white,
                    onTap: () => context.safePop(),
                  ),
                ),
              ),
              if (_loadState ==
                  _CameraLoadState
                      .ready) // TODO: restore `&& _maximumZoom > _minimumZoom` guard once done testing on emulator
                Positioned(
                  bottom: AppSpacing.md,
                  child: _ZoomPresets(
                    currentZoom: _displayZoom,
                    minimumZoom: _primaryMinimumZoom,
                    maximumZoom: _primaryMaximumZoom,
                    hasUltraWideLens: _canReachUltraWide,
                    onSelect: _handlePresetSelect,
                  ),
                ),
            ],
          ),
        ),
        CameraGridNavigator(
          grid: grid,
          activeCellIndex: activeCellId,
          cellQuality: widget.state.cellQuality,
          enabled: !_capturing,
          onCellSelected: context.read<CaptureSessionCubit>().openCell,
        ),
        _CaptureFooter(
          shotPaths: shotPaths,
          quality: widget.state.cellQuality[activeCellId],
          deletingPaths: _deletingPaths,
          onDelete: (path) => _handleDeletePhoto(activeCellId, path),
          onShutter:
              _loadState == _CameraLoadState.ready &&
                  !_capturing &&
                  !_switchingLens
              ? _handleShutter
              : null,
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.loadState,
    required this.errorMessage,
    required this.controller,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final _CameraLoadState loadState;
  final String? errorMessage;
  final CameraController? controller;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return switch (loadState) {
      _CameraLoadState.loading => const CircularProgressIndicator(
        color: Colors.white,
      ),
      _CameraLoadState.error => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Text(
          errorMessage ?? 'Camera unavailable.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      _CameraLoadState.ready => LayoutBuilder(
        builder: (context, constraints) {
          final cameraController = controller!;
          final previewSize = cameraController.value.previewSize;
          if (previewSize == null) {
            return CameraPreview(cameraController);
          }

          final portrait = constraints.maxHeight >= constraints.maxWidth;
          final previewWidth = portrait
              ? previewSize.shortestSide
              : previewSize.longestSide;
          final previewHeight = portrait
              ? previewSize.longestSide
              : previewSize.shortestSide;

          // Fill the whole available viewfinder instead of constraining the
          // camera to a centered landscape AspectRatio. BoxFit.cover keeps
          // the sensor image proportional and crops only the overflow, so the
          // capture surface is larger without stretching/compressing it.
          return GestureDetector(
            key: const ValueKey('camera-viewfinder'),
            behavior: HitTestBehavior.opaque,
            onScaleStart: onScaleStart,
            onScaleUpdate: onScaleUpdate,
            child: ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
                    child: CameraPreview(cameraController),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    };
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.cameraScrim,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

/// Quick-select zoom pills (0.5x / 1x / 2x), like a stock phone camera app,
/// on top of the continuous pinch-to-zoom gesture on the viewfinder. 1x/2x
/// are hidden when outside the primary lens's actual [minimumZoom,
/// maximumZoom] range; 0.5x is shown whenever [hasUltraWideLens] is true,
/// since selecting it switches to a second physical lens rather than
/// digitally zooming out past 1x (which isn't optically possible).
class _ZoomPresets extends StatelessWidget {
  const _ZoomPresets({
    required this.currentZoom,
    required this.minimumZoom,
    required this.maximumZoom,
    required this.hasUltraWideLens,
    required this.onSelect,
  });

  final double currentZoom;
  final double minimumZoom;
  final double maximumZoom;
  final bool hasUltraWideLens;
  final ValueChanged<double> onSelect;

  static const List<double> _presetLevels = [0.5, 1, 2];
  static const double _matchTolerance = 0.05;

  @override
  Widget build(BuildContext context) {
    final availablePresets = _presetLevels.where((level) {
      if (level < 1) return hasUltraWideLens;
      return level >= minimumZoom - _matchTolerance &&
          level <= maximumZoom + _matchTolerance;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: 'Camera zoom ${currentZoom.toStringAsFixed(1)} times',
          child: _DarkPill(label: '${currentZoom.toStringAsFixed(1)}×'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: AppColors.cameraScrim,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final level in availablePresets)
                  _ZoomPresetPill(
                    key: ValueKey('camera-zoom-preset-$level'),
                    level: level,
                    selected: (currentZoom - level).abs() < _matchTolerance,
                    onTap: () => onSelect(level),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomPresetPill extends StatelessWidget {
  const _ZoomPresetPill({
    super.key,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final double level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              _label(level),
              style: TextStyle(
                color: selected ? AppColors.cameraBackground : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _label(double level) {
    if (level < 1) return '${level.toStringAsFixed(1).substring(1)}×';
    if (level == level.roundToDouble()) return '${level.toInt()}×';
    return '${level.toStringAsFixed(1)}×';
  }
}

/// A persistent dark-translucent circular button. Visual diameter matches
/// the prototype's 36dp; the tap target is padded out to 48x48dp per
/// DESIGN_SYSTEM.md §9 (unlike the prototype, which has no accessibility
/// requirement to satisfy).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.cameraScrim,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggles auto-advance mode: when [enabled], a successful capture
/// automatically opens the next grid cell instead of leaving the operator
/// on the current one. Styled like [_RoundIconButton] but with a filled
/// accent background while enabled, so the mode's state stays visible
/// without needing to check a settings screen.
class _AutoAdvanceToggleButton extends StatelessWidget {
  const _AutoAdvanceToggleButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: enabled,
      label: 'Auto-advance to next cell',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.seed : AppColors.cameraScrim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.skip_next, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Persists whatever's been captured so far to the wall's grid, right from
/// the camera screen — the same action as coverage-review's "Save partial",
/// just reachable without leaving the capture flow first.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cameraScrim,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check,
                size: 18,
                color: onTap == null ? Colors.white38 : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                'Save',
                style: TextStyle(
                  color: onTap == null ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.shotPaths,
    required this.quality,
    required this.deletingPaths,
    required this.onDelete,
  });

  final List<String> shotPaths;

  /// This cell's quality result, if scored — carries every shot's own score
  /// via [CellQualityResult.scoreFor], not just the winning shot's.
  final CellQualityResult? quality;
  final Set<String> deletingPaths;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (shotPaths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shotPaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final path = shotPaths[index];
          return _ThumbnailTile(
            path: path,
            score: quality?.scoreFor(path),
            deleting: deletingPaths.contains(path),
            onDelete: () => onDelete(path),
          );
        },
      ),
    );
  }
}

/// Keeps the shutter and captured-image strip in one row so they no longer
/// consume two full rows below the camera. The reclaimed height belongs to the
/// live viewfinder, while the thumbnails are slightly larger than before.
class _CaptureFooter extends StatelessWidget {
  const _CaptureFooter({
    required this.shotPaths,
    required this.quality,
    required this.deletingPaths,
    required this.onDelete,
    required this.onShutter,
  });

  final List<String> shotPaths;
  final CellQualityResult? quality;
  final Set<String> deletingPaths;
  final ValueChanged<String> onDelete;
  final VoidCallback? onShutter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        GridCaptureMetrics.shutterBottomPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const shutterSize = 72.0;
          const sideGap = AppSpacing.md;
          final sideWidth =
              ((constraints.maxWidth - shutterSize - (sideGap * 2)) / 2)
                  .clamp(0.0, double.infinity)
                  .toDouble();

          return Row(
            children: [
              SizedBox(
                width: sideWidth,
                child: _ThumbnailStrip(
                  shotPaths: shotPaths,
                  quality: quality,
                  deletingPaths: deletingPaths,
                  onDelete: onDelete,
                ),
              ),
              const SizedBox(width: sideGap),
              _ShutterButton(onTap: onShutter),
              const SizedBox(width: sideGap),
              SizedBox(width: sideWidth),
            ],
          );
        },
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.path,
    required this.score,
    required this.deleting,
    required this.onDelete,
  });

  final String path;

  /// This specific shot's own score — a cell can hold several retakes, each
  /// scored independently, so this must never be the cell's overall/winning
  /// score unless [path] happens to be the winning shot.
  final ShotQualityScore? score;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GridCaptureMetrics.cameraThumbBackground,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: () => ImagePreviewDialog.show(context, path, score: score),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.image,
                    size: 22,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
          ),
          if (score != null)
            Positioned(
              bottom: 2,
              left: 2,
              child: IgnorePointer(child: QualityDot(tier: score!.tier, size: 10)),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                key: ValueKey('delete-photo-$path'),
                tooltip: 'Delete photo',
                padding: EdgeInsets.zero,
                onPressed: deleting ? null : onDelete,
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: deleting
                      ? const Padding(
                          padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
            width: 4,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Icon(
              Icons.photo_camera,
              size: 30,
              color: onTap == null
                  ? AppColors.cameraBackground.withValues(alpha: 0.3)
                  : AppColors.cameraBackground,
            ),
          ),
        ),
      ),
    );
  }
}
