import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Persistent, never-dismissible offline indicator — DESIGN_SYSTEM.md §2's
/// "offline-first visual honesty" principle. Shown whenever there is no
/// confirmed connectivity; a screen can be in its normal content state and
/// still show this above it.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      color: AppColors.warningContainer,
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            size: 18,
            color: AppColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'No connection — showing cached data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onWarningContainer,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Offline" pill for the app bar (paired with [OfflineBanner], not a
/// replacement for it).
class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.offlineIndicatorBackground,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 16,
            color: AppColors.offlineIndicatorForeground,
          ),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.offlineIndicatorForeground,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
