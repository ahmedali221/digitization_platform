import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/capture_quality.dart';
import '../theme/quality_tier_meta.dart';

/// Small heat-colored dot for dense contexts (grid tiles, the camera strip)
/// — the same continuous color language as [QualityBadge], spec §5, just
/// without room for the number.
class QualityDot extends StatelessWidget {
  const QualityDot({super.key, required this.tier, this.size = 12});

  final QualityTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tier.meta.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

/// The "will this stitch?" badge (spec §5): heat color + 0-100 score, plus
/// the single clearest failure reason once one applies (spec §6). Shown for
/// the active cell on the camera screen — Tier 1's result appears the
/// instant it's ready, then the badge updates in place as soon as Tier 2/3
/// lands for a captured neighbour.
class QualityBadge extends StatelessWidget {
  const QualityBadge({
    super.key,
    required this.result,
    this.analyzing = false,
    this.onToggleOverride,
  });

  final CellQualityResult? result;
  final bool analyzing;

  /// Called when the operator taps the "keep anyway" control — only shown
  /// for a red/orange [result] when this is non-null. Toggling never
  /// changes the score/color shown; see [CellQualityResult.overridden].
  final VoidCallback? onToggleOverride;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null && !analyzing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: result == null
          ? const _ScoringIndicator()
          : _BadgeContent(result: result, onToggleOverride: onToggleOverride),
    );
  }
}

class _ScoringIndicator extends StatelessWidget {
  const _ScoringIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          'Scoring…',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _BadgeContent extends StatelessWidget {
  const _BadgeContent({required this.result, this.onToggleOverride});

  final CellQualityResult result;
  final VoidCallback? onToggleOverride;

  bool get _canOverride =>
      result.tier == QualityTier.red || result.tier == QualityTier.orange;

  @override
  Widget build(BuildContext context) {
    final tier = result.tier;
    final score = result.cellScore.round();
    final failureReason = result.failureReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            QualityDot(tier: tier, size: 10),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$score · ${tier.meta.meaning}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (failureReason != null) ...[
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              failureReason,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
            ),
          ),
        ],
        if (_canOverride && onToggleOverride != null)
          _KeepAnywayToggle(overridden: result.overridden, onTap: onToggleOverride!),
      ],
    );
  }
}

/// Lets the operator explicitly accept a red/orange shot — e.g. the wall is
/// genuinely damaged there, or this is the best angle physically reachable.
/// Never changes the score/color above; only records that a human chose to
/// move on despite it (spec's own scores stay honest either way).
class _KeepAnywayToggle extends StatelessWidget {
  const _KeepAnywayToggle({required this.overridden, required this.onTap});

  final bool overridden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: overridden ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          key: const ValueKey('quality-keep-anyway-toggle'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  overridden ? Icons.check_circle : Icons.check_circle_outline,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  overridden ? 'Kept anyway' : 'Keep anyway',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
