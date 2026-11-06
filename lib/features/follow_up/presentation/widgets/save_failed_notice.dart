import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Says a save failed, from just above the button that retries it. Not a
/// snackbar, which would sit on top of that button and then time out.
class SaveFailedNotice extends StatelessWidget {
  const SaveFailedNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dangerContainer,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onDangerContainer),
        ),
      ),
    );
  }
}
