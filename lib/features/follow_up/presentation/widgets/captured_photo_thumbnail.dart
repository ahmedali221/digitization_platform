import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A photograph just taken, small enough to sit beside the shutter. Tapping it
/// opens it; [onTap] is null while the camera is busy. [label] names its grid
/// cell, when it has one.
class CapturedPhotoThumbnail extends StatelessWidget {
  const CapturedPhotoThumbnail({
    super.key,
    required this.path,
    required this.onTap,
    this.label,
  });

  static const double size = 64;

  final String path;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Semantics(
      button: true,
      label: label == null ? 'Open photograph' : 'Open photograph of $label',
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: AppColors.cameraScrim,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Shots are tens of megapixels and this tile is tiny: without
                // cacheWidth the decoder builds a full-size bitmap just to shrink it.
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, color: Colors.white70),
                ),
                if (label != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: AppColors.cameraScrim,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
