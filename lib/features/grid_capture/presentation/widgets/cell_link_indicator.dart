import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/capture_quality.dart';
import '../theme/link_status_meta.dart';

enum LinkAxis { horizontal, vertical }

/// Fixed thickness of the strip a [CellLinkIndicator] occupies between two
/// grid-adjacent cell tiles — wide enough to host the match-count badge
/// without stealing much space from the tiles themselves.
const double kCellLinkStripSize = 22;

/// The connector drawn between two grid-adjacent cell tiles on the
/// coverage-review grid: a colored line plus the RANSAC-inlier count that
/// backs [NeighbourMatchMetricsLinkX.linkStatus] (spec's "will this actually
/// stitch?" signal — see that extension's doc comment for why 12 inliers,
/// not raw SIFT keypoints or pre-RANSAC matches, is what's shown here).
///
/// [metrics] is null whenever the pair hasn't been scored yet (one or both
/// cells still lack a photo) — rendered as a neutral dashed line with no
/// badge, deliberately distinct from [LinkStatus.weak]'s red: "not yet known"
/// and "checked and it's weak" are different facts the operator shouldn't
/// confuse.
class CellLinkIndicator extends StatelessWidget {
  const CellLinkIndicator({super.key, required this.axis, this.metrics});

  final LinkAxis axis;
  final NeighbourMatchMetrics? metrics;

  bool get _isHorizontal => axis == LinkAxis.horizontal;

  @override
  Widget build(BuildContext context) {
    final metrics = this.metrics;
    final color = metrics == null ? AppColors.iconMuted : metrics.linkMeta.color;

    final line = _isHorizontal
        ? SizedBox(height: 2, child: ColoredBox(color: color))
        : SizedBox(width: 2, child: ColoredBox(color: color));

    return SizedBox(
      width: kCellLinkStripSize,
      height: kCellLinkStripSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: metrics == null
                ? _DashedLine(horizontal: _isHorizontal, color: color)
                : Center(child: line),
          ),
          if (metrics != null)
            Tooltip(
              message:
                  '${metrics.linkMeta.label} · ${metrics.ransacInliers} matched points',
              child: _MatchBadge(count: metrics.ransacInliers, color: color),
            ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// A thin dashed placeholder for a not-yet-scored link — drawn along the
/// strip's long axis (the same axis the solid line would occupy once scored)
/// so the layout doesn't shift once a score arrives.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.horizontal, required this.color});

  final bool horizontal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final length = horizontal ? constraints.maxWidth : constraints.maxHeight;
          const dash = 3.0;
          const gap = 3.0;
          final count = (length / (dash + gap)).floor();
          final children = [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: horizontal ? dash : 2,
                height: horizontal ? 2 : dash,
                child: ColoredBox(color: color.withValues(alpha: 0.5)),
              ),
          ];
          return horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: children,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: children,
                );
        },
      ),
    );
  }
}
