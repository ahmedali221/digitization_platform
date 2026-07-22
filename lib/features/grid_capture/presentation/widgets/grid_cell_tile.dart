import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import 'grid_capture_metrics.dart';

enum GridCellMode { capture, review }

/// One cell tile in the coverage grid, shared between the interactive
/// grid-capture screen ([GridCellMode.capture], tappable, shows a photo
/// count) and the read-only coverage-review screen ([GridCellMode.review],
/// not tappable, shows a covered/empty icon instead).
class GridCellTile extends StatelessWidget {
  const GridCellTile({
    super.key,
    required this.label,
    required this.photoCount,
    this.isSelected = false,
    this.mode = GridCellMode.capture,
    this.onTap,
  });

  final String label;
  final int photoCount;
  final bool isSelected;
  final GridCellMode mode;
  final VoidCallback? onTap;

  bool get _hasPhotos => photoCount > 0;

  @override
  Widget build(BuildContext context) {
    final capturedMeta = WallStatus.captured.meta;
    final background = isSelected
        ? capturedMeta.background
        : (_hasPhotos
              ? GridCaptureMetrics.cellFilledBackground
              : AppColors.surfaceNeutral);
    final border = isSelected
        ? AppColors.seed
        : (_hasPhotos ? capturedMeta.border : AppColors.outlineSubtle);
    final textColor = _hasPhotos ? AppColors.seed : AppColors.iconMuted;

    final content = Container(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Center(
        child: mode == GridCellMode.capture
            ? _CaptureContent(
                label: label,
                hasPhotos: _hasPhotos,
                photoCount: photoCount,
                color: textColor,
              )
            : _ReviewContent(
                label: label,
                hasPhotos: _hasPhotos,
                color: textColor,
              ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: content,
      ),
    );
  }
}

class _CaptureContent extends StatelessWidget {
  const _CaptureContent({
    required this.label,
    required this.hasPhotos,
    required this.photoCount,
    required this.color,
  });

  final String label;
  final bool hasPhotos;
  final int photoCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        if (hasPhotos)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera, size: 14, color: color),
              const SizedBox(width: 3),
              Text(
                '$photoCount',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 11, color: color),
              ),
            ],
          )
        else
          Icon(Icons.add_a_photo, size: 18, color: color),
      ],
    );
  }
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({
    required this.label,
    required this.hasPhotos,
    required this.color,
  });

  final String label;
  final bool hasPhotos;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontSize: 11, color: color),
        ),
        const SizedBox(height: 2),
        Icon(
          hasPhotos ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
      ],
    );
  }
}
