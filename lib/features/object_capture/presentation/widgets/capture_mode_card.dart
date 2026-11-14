import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// One way of photographing an object, offered on the mode screen: what it
/// is, what it asks for, and how far along it already is. A null [onTap]
/// shows the card as not available yet.
class CaptureModeCard extends StatelessWidget {
  const CaptureModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.onTap,
  });

  static const double _iconSize = 28;

  final IconData icon;
  final String title;
  final String description;

  /// "3 of 6 sides", "Coming soon" — the card's standing in a few words.
  final String progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = onTap != null;
    final foreground = isAvailable
        ? AppColors.textPrimary
        : AppColors.iconMuted;

    return Material(
      color: isAvailable ? Colors.white : AppColors.surfaceNeutral,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: _iconSize,
                color: isAvailable ? AppColors.seed : AppColors.iconMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      progress,
                      style: textTheme.labelSmall?.copyWith(
                        color: isAvailable
                            ? AppColors.seed
                            : AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAvailable)
                const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}
