import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The photograph a new target will be made from: a way to take it, then the
/// chosen shot with a way to take it again.
class NewTargetPhotoSection extends StatelessWidget {
  const NewTargetPhotoSection({super.key, required this.photoPath, required this.onTake, this.enabled = true});

  static const int _previewCacheWidth = 1200;

  final String? photoPath;
  final VoidCallback onTake;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final path = photoPath;

    if (path == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(AppSpacing.xl)),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Photograph the target'),
        onPressed: enabled ? onTake : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Photograph', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Image.file(File(path), cacheWidth: _previewCacheWidth),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            icon: const Icon(Icons.replay),
            label: const Text('Take it again'),
            onPressed: enabled ? onTake : null,
          ),
        ),
        Text(
          'Stand square to the wall and include all of the target, with some wall around it. '
          'Someone will straighten it on the dashboard.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}
