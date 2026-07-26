import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import 'grid_capture_metrics.dart';

enum GridCellMode { capture, review }

/// One cell tile in the coverage grid, shared between the interactive
/// grid-capture screen ([GridCellMode.capture], tappable, shows a photo
/// count) and the read-only coverage-review screen ([GridCellMode.review],
/// not tappable, shows a covered/empty icon instead). Shows [thumbnailPath]
/// as the tile's own background once a cell has a photo, rather than just a
/// flat "has photos" tint — a missing/undecodable file falls back to that
/// tint instead of crashing.
class GridCellTile extends StatelessWidget {
  const GridCellTile({
    super.key,
    required this.label,
    required this.photoCount,
    this.thumbnailPath,
    this.isSelected = false,
    this.mode = GridCellMode.capture,
    this.onTap,
  });

  final String label;
  final int photoCount;
  final String? thumbnailPath;
  final bool isSelected;
  final GridCellMode mode;
  final VoidCallback? onTap;

  bool get _hasPhotos => photoCount > 0;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = this.thumbnailPath;
    final capturedMeta = WallStatus.captured.meta;
    final background = isSelected
        ? capturedMeta.background
        : (_hasPhotos
              ? GridCaptureMetrics.cellFilledBackground
              : AppColors.surfaceNeutral);
    final border = isSelected
        ? AppColors.seed
        : (_hasPhotos ? capturedMeta.border : AppColors.outlineSubtle);
    final textColor = thumbnailPath != null
        ? Colors.white
        : (_hasPhotos ? AppColors.seed : AppColors.iconMuted);

    final overlay = mode == GridCellMode.capture
        ? _CaptureContent(
            label: label,
            hasPhotos: _hasPhotos,
            photoCount: photoCount,
            color: textColor,
          )
        : _ReviewContent(label: label, hasPhotos: _hasPhotos, color: textColor);

    final content = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailPath != null)
            Image.file(
              File(thumbnailPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          if (thumbnailPath != null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x73000000)],
                ),
              ),
            ),
          Center(child: overlay),
        ],
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
