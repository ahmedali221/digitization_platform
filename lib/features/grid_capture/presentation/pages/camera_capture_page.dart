import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/camera/camera_widgets.dart';
import '../../../../core/camera/capture_camera_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../data/datasources/camera_preferences_local_data_source.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/entities/capture_quality.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../../domain/services/cell_quality_analyzer.dart';
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
              GetIt.instance<CellQualityAnalyzer>(),
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

class _CameraBodyState extends State<_CameraBody> {
  late final CaptureCameraSession _camera;
  final Set<String> _deletingPaths = {};

  // When on, a successful capture automatically opens the next cell instead
  // of leaving the operator on the current one — see `_advanceToNextCell`.
  // Toggled by tapping the skip-next button rather than that button directly
  // advancing the cell. Seeded from [_preferences] in `initState` and
  // persisted on every toggle, so it carries forward to the next wall/room
  // instead of resetting — a fresh camera screen (and cubit) is created
  // every time the operator opens a different one.
  bool _autoAdvance = false;

  final CameraPreferencesLocalDataSource _preferences =
      GetIt.instance<CameraPreferencesLocalDataSource>();

  @override
  void initState() {
    super.initState();
    _autoAdvance = _preferences.getAutoAdvance();
    _camera = CaptureCameraSession(
      initialFlashModeName: _preferences.getFlashModeName(),
      onFlashModeChanged: (name) => unawaited(_preferences.setFlashModeName(name)),
      onMessage: _showMessage,
      onShutterPressed: _handleShutter,
    )..addListener(_onCameraChanged);
    _camera.start();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleShutter() => _camera.capture((file) async {
    if (!mounted) return;
    await context.read<CaptureSessionCubit>().takePhoto(file);
    if (_autoAdvance) _advanceToNextCell();
  });

  Future<void> _handleDeletePhoto(int cellId, String path) async {
    if (_camera.capturing || _camera.switchingLens || _deletingPaths.contains(path)) return;
    final confirmed = await _confirmDeletePhoto();
    if (!mounted || confirmed != true) return;
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

  Future<bool?> _confirmDeletePhoto() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This shot will be removed from the cell.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.onDangerContainer),
            ),
          ),
        ],
      ),
    );
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
  /// Persisted immediately so the next wall/room opens with the same choice.
  void _toggleAutoAdvance() {
    setState(() => _autoAdvance = !_autoAdvance);
    unawaited(_preferences.setAutoAdvance(_autoAdvance));
  }

  @override
  void dispose() {
    _camera
      ..removeListener(_onCameraChanged)
      ..dispose();
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
              CameraViewfinder(
                loadState: _camera.loadState,
                errorMessage: _camera.errorMessage,
                controller: _camera.controller,
                onScaleStart: _camera.onScaleStart,
                onScaleUpdate: _camera.onScaleUpdate,
              ),
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CameraPill(label: cellLabel),
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
                    _SaveButton(onTap: _camera.capturing ? null : _handleSave),
                    const SizedBox(height: AppSpacing.sm),
                    CameraFlashButton(mode: _camera.flashMode, onTap: _camera.cycleFlash),
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
                  child: CameraRoundButton(
                    icon: Icons.arrow_back,
                    iconColor: Colors.white,
                    onTap: () => context.safePop(),
                  ),
                ),
              ),
              if (_camera.loadState == CameraLoadState.ready) // TODO: restore `&& _maximumZoom > _minimumZoom` guard once done testing on emulator
                Positioned(
                  bottom: AppSpacing.md,
                  child: CameraZoomPresets(
                    currentZoom: _camera.displayZoom,
                    minimumZoom: _camera.primaryMinimumZoom,
                    maximumZoom: _camera.primaryMaximumZoom,
                    hasUltraWideLens: _camera.canReachUltraWide,
                    onSelect: _camera.selectZoomPreset,
                  ),
                ),
            ],
          ),
        ),
        CameraGridNavigator(
          grid: grid,
          activeCellIndex: activeCellId,
          cellQuality: widget.state.cellQuality,
          enabled: !_camera.capturing,
          onCellSelected: context.read<CaptureSessionCubit>().openCell,
        ),
        _CaptureFooter(
          shotPaths: shotPaths,
          quality: widget.state.cellQuality[activeCellId],
          deletingPaths: _deletingPaths,
          onDelete: (path) => _handleDeletePhoto(activeCellId, path),
          onShutter: _camera.canShoot ? _handleShutter : null,
        ),
      ],
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
            isMain: quality?.imagePath == path,
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
              CameraShutterButton(onTap: onShutter),
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
    required this.isMain,
    required this.deleting,
    required this.onDelete,
  });

  final String path;

  /// This specific shot's own score — a cell can hold several retakes, each
  /// scored independently, so this must never be the cell's overall/winning
  /// score unless [path] happens to be the winning shot.
  final ShotQualityScore? score;

  /// Whether this is the cell's current highest-scoring shot — the one
  /// [analyzeCellQuality] picked to drive the heat badge, stitching, and
  /// wall preview.
  final bool isMain;
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
              onTap: () => ImagePreviewDialog.show(context, path, score: score, isMain: isMain),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                // Shots are captured at ResolutionPreset.max (up to tens of
                // MP) but this tile is only 64 logical pixels wide — without
                // cacheWidth the decoder produces a full-resolution bitmap
                // just to shrink it for display, which is exactly the CPU
                // spike that makes the capture screen stutter right after
                // every shutter press (see grid_cell_tile.dart for the same
                // fix applied to the grid overview).
                cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context)).round(),
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
          if (isMain)
            Positioned(
              top: 2,
              left: 2,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.cameraScrim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Main',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
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
