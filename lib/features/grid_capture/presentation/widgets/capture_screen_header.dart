import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import 'grid_capture_metrics.dart';

/// Shared header shape for the grid-init, grid-capture, and coverage-review
/// screens: a back button + title row, followed by a muted subtitle line.
class CaptureScreenHeader extends StatelessWidget {
  const CaptureScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.subtitleBottomPadding = AppSpacing.lg,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final double subtitleBottomPadding;

  /// Optional action shown at the end of the title row (e.g. grid-capture's
  /// reshape entry point). Null for screens that don't need one.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleIconButton(
                icon: Icons.arrow_back,
                onTap: onBack,
                visualDiameter: 40,
                iconSize: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            GridCaptureMetrics.horizontalPadding,
            0,
            GridCaptureMetrics.horizontalPadding,
            subtitleBottomPadding,
          ),
          child: Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
      ],
    );
  }
}
