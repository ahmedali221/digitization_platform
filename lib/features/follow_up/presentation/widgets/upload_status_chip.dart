import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/follow_up_upload_record.dart';

/// What became of a photograph, in words the person holding the phone can act
/// on. A photograph that needs retaking says so.
class UploadStatus {
  const UploadStatus(this.label, this.background, this.foreground, {this.needsRetake = false});

  factory UploadStatus.of(FollowUpUploadRecord upload) {
    if (upload.status == FollowUpUploadRecord.statusFailed) {
      return const UploadStatus(
        'Not sent',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
        needsRetake: true,
      );
    }
    if (upload.status != FollowUpUploadRecord.statusSent) {
      return const UploadStatus('Waiting to send', AppColors.hoverSurface, AppColors.textSecondaryIcon);
    }
    return switch (upload.serverStatus) {
      'kept' when upload.grade == 'ok' => const UploadStatus(
        'Fixed',
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      'kept' => UploadStatus(
        'Kept, still ${upload.grade ?? 'not ok'}',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
        needsRetake: true,
      ),
      'reverted' => const UploadStatus(
        'Worse, so undone: retake',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
        needsRetake: true,
      ),
      'recheck_failed' => const UploadStatus(
        'Check failed on the server',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      'pending_review' => const UploadStatus(
        'Waiting for review',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      'approved' || 'pushed' || 'push_failed' => const UploadStatus(
        'Approved, target replaced',
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      'rejected' => const UploadStatus(
        'Rejected: retake',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
        needsRetake: true,
      ),
      'superseded' => const UploadStatus('Replaced by a later one', AppColors.hoverSurface, AppColors.textSecondaryIcon),
      _ => const UploadStatus('Sent, checking', AppColors.hoverSurface, AppColors.textSecondaryIcon),
    };
  }

  final String label;
  final Color background;
  final Color foreground;
  final bool needsRetake;
}

class UploadStatusChip extends StatelessWidget {
  const UploadStatusChip({super.key, required this.upload});

  final FollowUpUploadRecord upload;

  @override
  Widget build(BuildContext context) {
    final status = UploadStatus.of(upload);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: status.foreground),
      ),
    );
  }
}
