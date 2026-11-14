import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shown before any photograph is taken. The phone tells one side of the
/// object from another only by how far it has turned since the scan began,
/// so the scan begins, or is picked up again, from a place the operator
/// chooses on purpose.
class ScanAlignmentPrompt extends StatelessWidget {
  const ScanAlignmentPrompt({
    super.key,
    required this.isContinuing,
    required this.onAligned,
  });

  /// The scan already has photographs, so the place is where it began.
  final bool isContinuing;
  final VoidCallback onAligned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cameraScrim,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isContinuing
                ? 'Stand where you took the first photograph and point the '
                      'phone at the object.'
                : 'Stand in front of the object so that all of it is in the '
                      'picture. Then walk slowly round it, at the same '
                      'distance: the photographs are taken for you.\n\n'
                      'Do not touch or move the object until the scan is '
                      'finished.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onAligned,
            child: Text(isContinuing ? 'I am there' : 'Start'),
          ),
        ],
      ),
    );
  }
}
