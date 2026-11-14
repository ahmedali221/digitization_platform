import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/thin_progress_bar.dart';
import '../../domain/entities/scan_preview.dart';
import 'scan_model_viewer.dart';

/// The rough model of a scan: the model itself once it is here, with how
/// much of the object it lacks; until then, how far its build has got.
class ScanPreviewPanel extends StatelessWidget {
  const ScanPreviewPanel({super.key, required this.preview});

  /// Holes smaller than this share of the surface are not worth a mention:
  /// every model has pinholes.
  static const _worthMentioning = 0.02;

  final ScanPreview preview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final modelPath = preview.modelPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rough 3D model', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (preview.canBeShown && modelPath != null) ...[
          ScanModelViewer(modelPath: modelPath),
          const SizedBox(height: AppSpacing.md),
          Text(_whatIsMissing(preview), style: textTheme.bodyMedium),
        ] else if (preview.stage == ScanPreviewStage.unavailable)
          Text(
            'A rough model could not be built from these photographs.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          )
        else ...[
          Text(
            preview.stage == ScanPreviewStage.waiting
                ? 'Waiting for a processing machine. Stay near the object: '
                      'the model shows which parts still need photographing.'
                : 'Being built from the photographs. Stay near the object: '
                      'it shows which parts still need photographing.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ThinProgressBar(progress: preview.progress),
        ],
      ],
    );
  }

  static String _whatIsMissing(ScanPreview preview) {
    final holes = preview.unseenFraction;
    if (holes == null || holes < _worthMentioning) {
      return 'Turn the model with a finger to check it. A part that is '
          'missing here was not photographed.';
    }
    return 'About ${(holes * 100).round()}% of the surface is holes: parts '
        'no photograph showed. Turn the model with a finger to find them.';
  }
}
