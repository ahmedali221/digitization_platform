import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'primary_action_button.dart';

/// Standard empty-state shape (DESIGN_SYSTEM.md §8) — icon + message +
/// optional action, used for every empty list in the app.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.iconMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryActionButton(label: actionLabel!, onTap: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard loading shape — full-screen variant. No bare
/// [CircularProgressIndicator] in feature code (DESIGN_SYSTEM.md §7.1).
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.inline = false});

  final bool inline;

  @override
  Widget build(BuildContext context) {
    final spinner = const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
    return inline ? spinner : Center(child: spinner);
  }
}

/// Standard error shape — message + Retry, never a raw exception string.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.onDangerContainer,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryActionButton(label: 'Retry', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
