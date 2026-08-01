import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../data/datasources/unassigned_capture_local_data_source.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import '../cubit/unassigned_capture_cubit.dart';
import '../cubit/unassigned_capture_state.dart';

/// Flat (no-grid) capture screen for an off-map wall — Phase 5's "treat
/// photos as a flat list (no grid)" guidance, since grid registration
/// against a `local_id` isn't supported server-side. A trimmed-down sibling
/// of `CameraCapturePage`: no grid-cell navigator/label, no zoom/exposure
/// controls (a reasonable MVP cut for this secondary flow — see Phase 8
/// "field polish" for whether those are worth adding here later).
class UnassignedCameraPage extends StatelessWidget {
  const UnassignedCameraPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.localId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String localId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UnassignedCaptureCubit(
        GetIt.instance<UnassignedWallRepository>(),
        GetIt.instance<UnassignedCaptureLocalDataSource>(),
      )..init(localId: localId, siteId: siteId, floorId: floorId),
      child: Scaffold(
        backgroundColor: AppColors.cameraBackground,
        body: SafeArea(
          child: BlocBuilder<UnassignedCaptureCubit, UnassignedCaptureState>(
            builder: (context, state) => switch (state) {
              UnassignedCaptureLoading() => const LoadingIndicator(),
              UnassignedCaptureError(:final message) => ErrorRetryView(
                message: message,
                onRetry: () => context.read<UnassignedCaptureCubit>().init(
                  localId: localId,
                  siteId: siteId,
                  floorId: floorId,
                ),
              ),
              UnassignedCaptureLoaded() => _CameraBody(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _CameraBody extends StatefulWidget {
  const _CameraBody({required this.state});

  final UnassignedCaptureLoaded state;

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
      await context.read<UnassignedCaptureCubit>().takePhoto(file);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _handleDeletePhoto(String path) async {
    if (_capturing || _deletingPaths.contains(path)) return;
    setState(() => _deletingPaths.add(path));
    try {
      await context.read<UnassignedCaptureCubit>().deletePhoto(path);
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shotPaths = widget.state.shotPaths;

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
                child: _DarkPill(label: '${shotPaths.length} photos'),
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _DoneButton(onTap: _capturing ? null : context.safePop),
              ),
              Positioned(
                top: AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.safePop(),
                  ),
                ),
              ),
            ],
          ),
        ),
        _CaptureFooter(
          shotPaths: shotPaths,
          deletingPaths: _deletingPaths,
          onDelete: _handleDeletePhoto,
          onShutter: _loadState == _CameraLoadState.ready && !_capturing
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

          return ClipRect(
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
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
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

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
                'Done',
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

class _CaptureFooter extends StatelessWidget {
  const _CaptureFooter({
    required this.shotPaths,
    required this.deletingPaths,
    required this.onDelete,
    required this.onShutter,
  });

  final List<String> shotPaths;
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
        AppSpacing.lg,
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

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.shotPaths,
    required this.deletingPaths,
    required this.onDelete,
  });

  final List<String> shotPaths;
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
            deleting: deletingPaths.contains(path),
            onDelete: () => onDelete(path),
          );
        },
      ),
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.path,
    required this.deleting,
    required this.onDelete,
  });

  final String path;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.outlineSubtle,
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
            top: 0,
            right: 0,
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
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
