import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-width filled button — the primary capture/save/download action
/// shape used throughout the app. Supports a disabled visual state that
/// still renders (never literally removed) when an action is gated on a
/// condition like "all cells covered".
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? AppColors.seed : AppColors.outlineSubtle;
    final fg = enabled ? Colors.white : AppColors.iconMuted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: fg, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined button — secondary action (e.g. "Save partial",
/// "Download").
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.borderColor = AppColors.seed,
    this.textColor = AppColors.seed,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
