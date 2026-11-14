import 'package:flutter/material.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Where a wall or object stands between this phone and the dashboard, for
/// the cases worth saying: it is waiting for someone to accept it, or it was
/// added here and has or has not been sent yet. Draws nothing for an
/// ordinary record that came down in a package.
class ItemSyncChip extends StatelessWidget {
  const ItemSyncChip({super.key, required this.wall});

  static const double _iconSize = 12;

  final WallEntity wall;

  @override
  Widget build(BuildContext context) {
    final standing = _Standing.of(wall);
    if (standing == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: standing.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(standing.icon, size: _iconSize, color: standing.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            standing.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: standing.foreground),
          ),
        ],
      ),
    );
  }
}

class _Standing {
  const _Standing({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  static const _awaitingReview = _Standing(
    label: 'Awaiting review',
    icon: Icons.hourglass_top,
    background: AppColors.warningContainer,
    foreground: AppColors.onWarningContainer,
  );

  static const _onThisPhone = _Standing(
    label: 'On this phone',
    icon: Icons.smartphone,
    background: AppColors.hoverSurface,
    foreground: AppColors.onSurfaceMuted,
  );

  static const _synced = _Standing(
    label: 'Synced',
    icon: Icons.cloud_done,
    background: AppColors.successContainer,
    foreground: AppColors.onSuccessContainer,
  );

  /// Review comes first: an item waiting for a decision is the one thing
  /// about it the operator can do nothing about from here.
  static _Standing? of(WallEntity wall) {
    if (wall.isAwaitingReview) return _awaitingReview;
    if (wall.isOnlyOnThisPhone) return _onThisPhone;
    if (wall.isLocal) return _synced;
    return null;
  }

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}
