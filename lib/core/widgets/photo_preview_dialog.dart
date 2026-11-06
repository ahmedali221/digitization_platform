import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-screen, pinch-to-zoom view of a captured photo, for checking focus and
/// framing without leaving a capture flow. [badge] says what the photo is, and
/// [actions] are what can be done with it, side by side along the bottom.
class PhotoPreviewDialog extends StatelessWidget {
  const PhotoPreviewDialog({
    super.key,
    required this.path,
    this.badge,
    this.actions = const [],
  });

  static const double _closeButtonSize = 48;
  static const double _maximumZoom = 4;

  final String path;
  final Widget? badge;
  final List<Widget> actions;

  /// Opens the preview [builder] returns, which can pop with a result of [T].
  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: _maximumZoom,
              child: Center(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: SafeArea(child: badge),
            ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: SafeArea(
              child: SizedBox.square(
                dimension: _closeButtonSize,
                child: Material(
                  color: AppColors.cameraScrim,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: SafeArea(
                child: Row(
                  children: [
                    for (final (index, action) in actions.indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(child: action),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
