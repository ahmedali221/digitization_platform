import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/thin_progress_bar.dart';
import '../../domain/entities/object_scan.dart';

/// Where a scan stands after shooting: what is happening to it, in words,
/// how far along that is, and what the server found wrong if anything.
class ScanStagePanel extends StatelessWidget {
  const ScanStagePanel({super.key, required this.scan});

  final ObjectScan scan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, colour, title, detail) = _describe(scan);
    final progress = _progress(scan);
    final reasons = scan.server?.reasons ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colour),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.md),
          ThinProgressBar(progress: progress),
        ],
        for (final reason in reasons) ...[
          const SizedBox(height: AppSpacing.md),
          Text(reason, style: textTheme.bodyMedium),
        ],
      ],
    );
  }

  static (IconData, Color, String, String) _describe(ObjectScan scan) {
    final count = scan.shots.length;
    return switch (scan.stage) {
      ScanStage.capturing => (
        Icons.photo_camera_outlined,
        AppColors.seed,
        'Scan not finished',
        '$count photographs taken so far.',
      ),
      ScanStage.uploading => (
        Icons.cloud_upload_outlined,
        AppColors.seed,
        'Sending the photographs',
        '${scan.uploadedCount} of $count sent. This continues by itself '
            'whenever the phone is online.',
      ),
      ScanStage.checking => (
        Icons.manage_search,
        AppColors.seed,
        'Checking the photographs',
        'Stay near the object: in a few minutes this says whether every '
            'side was covered.',
      ),
      ScanStage.needsMorePhotos => (
        Icons.error_outline,
        AppColors.onWarningContainer,
        'More photographs are needed',
        'Some of the object could not be put together from what was shot.',
      ),
      ScanStage.buildingModel => (
        Icons.check_circle_outline,
        AppColors.onSuccessContainer,
        'The photographs are enough',
        'The full 3D model is being built for the dashboard. Before leaving '
            'the object, check the rough model below for missing parts.',
      ),
      ScanStage.modelReady => (
        Icons.view_in_ar,
        AppColors.onSuccessContainer,
        'The 3D model is ready',
        'It can be viewed on the dashboard.',
      ),
      ScanStage.failed => (
        Icons.error_outline,
        AppColors.onDangerContainer,
        'The scan could not be processed',
        scan.server?.failureReason ?? 'Something went wrong on the server.',
      ),
      ScanStage.cancelled => (
        Icons.block,
        AppColors.onSurfaceMuted,
        'The scan was cancelled',
        'It was cancelled on the dashboard.',
      ),
    };
  }

  /// How far the current step is, for the steps that can say.
  static double? _progress(ObjectScan scan) => switch (scan.stage) {
    ScanStage.uploading =>
      scan.shots.isEmpty ? 0 : scan.uploadedCount / scan.shots.length,
    ScanStage.checking || ScanStage.buildingModel => scan.server?.runProgress,
    _ => null,
  };
}
