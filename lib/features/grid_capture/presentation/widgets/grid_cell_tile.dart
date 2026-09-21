import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../domain/entities/capture_quality.dart';
import '../theme/quality_tier_meta.dart';
import 'grid_capture_metrics.dart';
import 'quality_badge.dart';

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
    this.qualityTier,
    this.qualityScore,
    this.onTap,
  });

  final String label;
  final int photoCount;
  final String? thumbnailPath;
  final bool isSelected;
  final GridCellMode mode;

  /// Capture Quality Indicator heat color for this cell's current shot
  /// (spec §5) — null while unscored or empty; never shown without a photo.
  final QualityTier? qualityTier;

  /// [CellQualityResult.cellScore], rounded — shown alongside the tier dot
  /// on the coverage-review grid only (spec's badge already shows this on
  /// the camera screen; the grid tile had no room for it before). Null
  /// whenever [qualityTier] is null.
  final int? qualityScore;
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
              // Shots are captured at ResolutionPreset.max (up to tens of MP)
              // but this tile is never more than a couple hundred logical
              // pixels wide — decoding full-resolution just to shrink it for
              // display burns CPU on every grid rebuild for no visual gain.
              // cacheWidth makes the decoder itself downsample.
              cacheWidth: (240 * MediaQuery.devicePixelRatioOf(context)).round(),
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
          if (qualityTier != null)
            Positioned(
              top: 6,
              right: 6,
              child: qualityScore == null
                  ? QualityDot(tier: qualityTier!)
                  : _ScoreChip(tier: qualityTier!, score: qualityScore!),
            ),
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

/// [QualityDot] with the numeric score alongside it — the coverage-review
/// grid has room a dense per-cell tile doesn't, so it doesn't need to make
/// the operator open the camera screen's badge just to see the number.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.tier, required this.score});

  final QualityTier tier;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: tier.meta.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
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
