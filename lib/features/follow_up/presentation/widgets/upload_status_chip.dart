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
      final tiles = upload.tiles;
      final sent = tiles.where((tile) => tile.sent).length;
      return UploadStatus(
        sent > 0 ? 'Sent $sent of ${tiles.length}, the rest waiting' : 'Waiting to send',
        AppColors.hoverSurface,
        AppColors.textSecondaryIcon,
      );
    }
    if (upload.kind == FollowUpUploadRecord.kindWidth) {
      return switch (upload.serverStatus) {
        'held' => const UploadStatus(
          'Width waiting in the studio',
          AppColors.warningContainer,
          AppColors.onWarningContainer,
        ),
        'kept' => const UploadStatus(
          'The studio kept its width',
          AppColors.hoverSurface,
          AppColors.textSecondaryIcon,
        ),
        // Saved as soon as the dashboard has it; reaching the studio is its job from there.
        _ => const UploadStatus('Width saved', AppColors.successContainer, AppColors.onSuccessContainer),
      };
    }
    if (upload.isNewTarget) return UploadStatus._ofNewTarget(upload.serverStatus);
    return switch (upload.serverStatus) {
      'receiving' || 'stitching' => const UploadStatus(
        'Stitching on the dashboard',
        AppColors.hoverSurface,
        AppColors.textSecondaryIcon,
      ),
      'needs_decision' => const UploadStatus(
        'Part did not join: your choice',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      'stitch_failed' => const UploadStatus(
        'Could not stitch: retake',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
        needsRetake: true,
      ),
      'declined' => const UploadStatus(
        'Not used: retake',
        AppColors.hoverSurface,
        AppColors.textSecondaryIcon,
        needsRetake: true,
      ),
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
        'Approved, waiting for the studio',
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      ),
      'studio_approved' => const UploadStatus(
        'Approved, target replaced',
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      ),
      'studio_rejected' => const UploadStatus(
        'Rejected by the studio: retake',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
        needsRetake: true,
      ),
      'refused' => const UploadStatus(
        'Refused',
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
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

  /// A target the site had no profile for: reviewed on the dashboard, then made
  /// a profile by the studio, after which the next package lists it.
  factory UploadStatus._ofNewTarget(String? serverStatus) => switch (serverStatus) {
    'pending_review' => const UploadStatus(
      'Waiting for review',
      AppColors.warningContainer,
      AppColors.onWarningContainer,
    ),
    'approved' || 'push_failed' => const UploadStatus(
      'Approved, the studio is making it',
      AppColors.warningContainer,
      AppColors.onWarningContainer,
    ),
    'created' => const UploadStatus(
      'Created in the studio',
      AppColors.successContainer,
      AppColors.onSuccessContainer,
    ),
    'rejected' => const UploadStatus(
      'Rejected: add it again',
      AppColors.dangerContainer,
      AppColors.onDangerContainer,
      needsRetake: true,
    ),
    _ => const UploadStatus('Sent, checking', AppColors.hoverSurface, AppColors.textSecondaryIcon),
  };

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
