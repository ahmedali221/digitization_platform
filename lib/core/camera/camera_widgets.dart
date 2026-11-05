import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'capture_camera_session.dart';

class CameraViewfinder extends StatelessWidget {
  const CameraViewfinder({
    super.key,
    required this.loadState,
    required this.errorMessage,
    required this.controller,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final CameraLoadState loadState;
  final String? errorMessage;
  final CameraController? controller;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return switch (loadState) {
      CameraLoadState.loading => const CircularProgressIndicator(
        color: Colors.white,
      ),
      CameraLoadState.error => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Text(
          errorMessage ?? 'Camera unavailable.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      CameraLoadState.ready => LayoutBuilder(
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

class CameraPill extends StatelessWidget {
  const CameraPill({super.key, required this.label});

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
class CameraZoomPresets extends StatelessWidget {
  const CameraZoomPresets({
    super.key,
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
  static const double _matchTolerance = CaptureCameraSession.zoomMatchTolerance;

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
          child: CameraPill(label: '${currentZoom.toStringAsFixed(1)}×'),
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
class CameraRoundButton extends StatelessWidget {
  const CameraRoundButton({
    super.key,
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

/// Cycles the controller's flash mode (off -> auto -> torch). Styled like
/// [the auto-advance toggle] — filled accent background whenever the mode
/// isn't off, so the operator can tell at a glance the flash won't behave
/// unpredictably shot-to-shot.
class CameraFlashButton extends StatelessWidget {
  const CameraFlashButton({super.key, required this.mode, required this.onTap});

  final FlashMode mode;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
    FlashMode.off => Icons.flash_off,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.torch || FlashMode.always => Icons.flash_on,
  };

  String get _label => switch (mode) {
    FlashMode.off => 'Flash off',
    FlashMode.auto => 'Flash automatic',
    FlashMode.torch || FlashMode.always => 'Flash on',
  };

  @override
  Widget build(BuildContext context) {
    final enabled = mode != FlashMode.off;
    return Semantics(
      toggled: enabled,
      label: _label,
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
                child: Icon(_icon, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CameraShutterButton extends StatelessWidget {
  const CameraShutterButton({super.key, required this.onTap});

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
