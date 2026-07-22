import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// One entry in a [Breadcrumb] trail — [onTap] is null for the current page
/// (the trail's last item), which is never tappable.
class BreadcrumbItem {
  const BreadcrumbItem({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

/// Horizontal trail of ancestor screens (e.g. Sites > Saqqara North >
/// Mastaba A) shown above a page's title so the user always knows where they
/// stand in the building -> floor -> wall hierarchy. The last item is the
/// current page — bold and not tappable; every earlier item navigates back
/// to that level.
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.items});

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.iconMuted,
              ),
            ),
          _BreadcrumbLabel(item: items[i], isCurrent: i == items.length - 1),
        ],
      ],
    );
  }
}

class _BreadcrumbLabel extends StatelessWidget {
  const _BreadcrumbLabel({required this.item, required this.isCurrent});

  final BreadcrumbItem item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 13,
      color: isCurrent ? AppColors.textPrimary : AppColors.onSurfaceMuted,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
    );
    final text = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    if (isCurrent || item.onTap == null) return text;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: text,
      ),
    );
  }
}
