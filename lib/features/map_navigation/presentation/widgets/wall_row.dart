import 'package:flutter/material.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';
import '../../../../core/widgets/status_chip.dart';
import 'item_sync_chip.dart';

/// Single wall or object row inside the room sheet (DESIGN_SYSTEM.md §7.2's
/// `WallRow`): name + last capture on the left, status chip + chevron on the
/// right. An object also says what it is, and an item added on this phone
/// where it stands with the dashboard.
class WallRow extends StatelessWidget {
  const WallRow({
    super.key,
    required this.wall,
    required this.onTap,
    required this.isLast,
  });

  static const double _minHeight = 48;
  static const double _chevronSize = 18;

  /// The most of a row its chips may take, leaving the name the rest.
  static const double _chipsMaxWidthFraction = 0.5;

  final WallEntity wall;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isObject = wall.objectType != ObjectType.wall;
    final caption = [
      if (isObject) wall.objectType.meta.label,
      wall.lastCapture,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hoverSurface)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (isObject) ...[
                Icon(wall.objectType.meta.icon, color: AppColors.iconMuted),
                const SizedBox(width: AppSpacing.md),
              ],
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
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      caption,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.iconMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _chipsMaxWidthFraction,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ItemSyncChip(wall: wall),
                    StatusChip(status: wall.status, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right,
                color: AppColors.iconMuted,
                size: _chevronSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
