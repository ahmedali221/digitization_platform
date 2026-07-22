import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../domain/entities/unassigned_wall.dart';

/// A single captured-before-assignment wall row: thumbnail placeholder,
/// local-ID badge (+ required-note flag), photo count, and a chevron
/// affordance (DESIGN_SYSTEM.md §7.2, Phase 5 `UnassignedWallCard`).
class UnassignedWallCard extends StatelessWidget {
  const UnassignedWallCard({super.key, required this.item, this.onTap});

  final UnassignedWall item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.outlineSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(
                  Icons.image,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.hoverSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.localId,
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryIcon,
                            ),
                          ),
                        ),
                        if (item.noteRequired) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.flag,
                            size: 16,
                            color:
                                kWallStatusMeta[WallStatus.inProgress]!.color,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.photoCount} photos captured',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
