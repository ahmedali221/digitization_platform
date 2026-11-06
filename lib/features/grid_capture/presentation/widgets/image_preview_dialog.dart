import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/photo_preview_dialog.dart';
import '../../domain/entities/capture_quality.dart';
import '../theme/quality_tier_meta.dart';
import 'quality_badge.dart';

/// Full-screen, pinch-to-zoom preview of a captured photo. Opened from a
/// thumbnail tap so the operator can check focus/framing without leaving
/// the capture flow. [score], when given, is THIS specific shot's own
/// Capture Quality Indicator result — a cell can hold several retakes, and
/// each one scores independently (see `CellQualityResult.allShotScores`),
/// so this must never default to the cell's overall/winning score.
class ImagePreviewDialog extends StatelessWidget {
  const ImagePreviewDialog({
    super.key,
    required this.path,
    this.score,
    this.isMain = false,
  });

  final String path;
  final ShotQualityScore? score;

  /// Whether [path] is the cell's current highest-scoring shot — mirrors the
  /// "Main" pill shown on its thumbnail in the capture footer.
  final bool isMain;

  static Future<void> show(
    BuildContext context,
    String path, {
    ShotQualityScore? score,
    bool isMain = false,
  }) {
    return PhotoPreviewDialog.show<void>(
      context,
      (_) => ImagePreviewDialog(path: path, score: score, isMain: isMain),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhotoPreviewDialog(
      path: path,
      badge: score != null || isMain
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (score != null) _ShotScoreBadge(score: score!),
                if (score != null && isMain) const SizedBox(width: AppSpacing.xs),
                if (isMain) const _MainBadge(),
              ],
            )
          : null,
    );
  }
}

/// Mirrors the "Main" pill shown on this shot's thumbnail in the capture
/// footer — same word, same visual language, wherever the shot is shown.
class _MainBadge extends StatelessWidget {
  const _MainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cameraScrim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Main',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ShotScoreBadge extends StatelessWidget {
  const _ShotScoreBadge({required this.score});

  final ShotQualityScore score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cameraScrim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QualityDot(tier: score.tier, size: 10),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${score.cellScore.round()} · ${score.tier.meta.meaning}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
