import 'package:flutter/material.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/status_chip.dart';

/// Single wall row inside the room sheet (DESIGN_SYSTEM.md §7.2's `WallRow`):
/// name + last capture on the left, status chip + chevron on the right.
class WallRow extends StatelessWidget {
  const WallRow({
    super.key,
    required this.wall,
    required this.onTap,
    required this.isLast,
  });

  final WallEntity wall;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hoverSurface)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wall.name,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wall.lastCapture,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusChip(status: wall.status, dense: true),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
