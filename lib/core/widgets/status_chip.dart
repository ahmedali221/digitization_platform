import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/wall_status.dart';

/// Wall/aggregate status → color + icon + label. Never color alone
/// (colorblind-safe — DESIGN_SYSTEM.md §7, §9).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});

  final WallStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final meta = status.meta;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : AppSpacing.sm,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: dense ? 12 : 15, color: meta.color),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style:
                (dense
                        ? Theme.of(context).textTheme.labelSmall
                        : Theme.of(context).textTheme.labelLarge)
                    ?.copyWith(color: meta.color, fontSize: dense ? 11 : 12),
          ),
        ],
      ),
    );
  }
}

/// Small legend dot + label, used in the status legend row on the site
/// overview screen — no icon, just color + text (legend already carries
/// the icon meaning via the adjacent StatusChip usages elsewhere).
///
/// Doubles as a filter toggle when [onTap] is set (FLUTTER_MOBILE_PLAN.md
/// §2's "status color legend + filter toggle" — tapping a status dims every
/// canvas shape that doesn't match it).
class StatusLegendItem extends StatelessWidget {
  const StatusLegendItem({
    super.key,
    required this.status,
    this.selected = false,
    this.onTap,
  });

  final WallStatus status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = status.meta;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          meta.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? meta.color : const Color(0xFF374151),
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }
}
