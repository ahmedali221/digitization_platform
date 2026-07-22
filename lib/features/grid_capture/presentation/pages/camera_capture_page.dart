import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../cubit/capture_session_cubit.dart';
import '../cubit/capture_session_state.dart';
import '../widgets/grid_capture_metrics.dart';

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
              CaptureSessionLoaded() => _CameraBody(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _CameraBody extends StatefulWidget {
  const _CameraBody({required this.state});

  final CaptureSessionLoaded state;

  @override
  State<_CameraBody> createState() => _CameraBodyState();
}

enum _CameraLoadState { loading, ready, error }

class _CameraBodyState extends State<_CameraBody> {
  CameraController? _controller;
  _CameraLoadState _loadState = _CameraLoadState.loading;
  String? _errorMessage;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loadState = _CameraLoadState.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadState = _CameraLoadState.error;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _handleShutter() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      await context.read<CaptureSessionCubit>().takePhoto(file);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _handleExposureToggle() async {
    final controller = _controller;
    final cubit = context.read<CaptureSessionCubit>();
    final nextLocked = !widget.state.exposureLocked;
    cubit.toggleExposureLock();
    if (controller == null) return;
    await controller.setExposureMode(
      nextLocked ? ExposureMode.locked : ExposureMode.auto,
    );
  }

  @override
  void dispose() {
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
              ),
              Positioned(
                top: AppSpacing.lg,
                left: AppSpacing.lg,
                child: _DarkPill(label: cellLabel),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _RoundIconButton(
                  icon: Icons.lock,
                  iconColor: widget.state.exposureLocked
                      ? WallStatus.inProgress.meta.border
                      : Colors.white,
                  onTap: _handleExposureToggle,
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
            ],
          ),
        ),
        _ThumbnailStrip(shotPaths: shotPaths),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.lg,
            0,
            GridCaptureMetrics.shutterBottomPadding,
          ),
          child: _ShutterButton(
            onTap: _loadState == _CameraLoadState.ready && !_capturing
                ? _handleShutter
                : null,
          ),
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
  });

  final _CameraLoadState loadState;
  final String? errorMessage;
  final CameraController? controller;

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
      _CameraLoadState.ready => AspectRatio(
        aspectRatio: controller!.value.aspectRatio,
        child: CameraPreview(controller!),
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

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({required this.shotPaths});

  final List<String> shotPaths;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: shotPaths.isEmpty
          ? const SizedBox.shrink()
          : SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shotPaths.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _ThumbnailTile(path: shotPaths[index]),
              ),
            ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GridCaptureMetrics.cameraThumbBackground,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Stack(
        children: [
          Positioned.fill(
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
          Positioned(
            top: 2,
            right: 2,
            // Delete is a no-op stub — retake/delete management is a
            // separate future task, not part of wiring up capture itself.
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
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
