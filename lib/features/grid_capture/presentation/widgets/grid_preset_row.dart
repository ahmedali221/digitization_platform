import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// One row in the grid-init "Presets" list — a fixed rows x cols option the
/// operator can tap to jump straight into grid capture.
class GridPresetRow extends StatelessWidget {
  const GridPresetRow({
    super.key,
    required this.label,
    required this.cellCount,
    required this.onTap,
  });

  final String label;
  final int cellCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md + 2,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineSubtle, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view, size: 22, color: AppColors.seed),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$cellCount cells',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
