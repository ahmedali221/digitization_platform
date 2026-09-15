import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Full-screen, pinch-to-zoom preview of a captured photo. Opened from a
/// thumbnail tap so the operator can check focus/framing without leaving
/// the capture flow.
class ImagePreviewDialog extends StatelessWidget {
  const ImagePreviewDialog({super.key, required this.path});

  final String path;

  static Future<void> show(BuildContext context, String path) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => ImagePreviewDialog(path: path),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
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
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: SafeArea(
              child: SizedBox(
                width: 40,
                height: 40,
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
        ],
      ),
    );
  }
}
