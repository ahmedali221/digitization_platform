import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/thin_progress_bar.dart';
import '../../domain/entities/sync_item.dart';

class _SyncStatusMeta {
  const _SyncStatusMeta({
    required this.background,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color color;
  final IconData icon;
  final String label;
}

/// Sync-item status chip styling — a feature-local counterpart to
/// `kWallStatusMeta` (this is a distinct status taxonomy from `WallStatus`,
/// so it isn't merged into that map). [_uploadingBackground] and
/// [_confirmedColor] have no existing DESIGN_SYSTEM.md token, so they're
/// defined here rather than added to the shared `AppColors`; every other
/// value reuses an existing token.
const _uploadingBackground = Color(0xFFDBEAFE);
const _confirmedColor = Color(0xFF059669);

const Map<SyncItemStatus, _SyncStatusMeta> _kSyncStatusMeta = {
  SyncItemStatus.queued: _SyncStatusMeta(
    background: AppColors.hoverSurface,
    color: AppColors.onSurfaceMuted,
    icon: Icons.schedule,
    label: 'Queued',
  ),
  SyncItemStatus.uploading: _SyncStatusMeta(
    background: _uploadingBackground,
    color: AppColors.seed,
    icon: Icons.cloud_upload,
    label: 'Uploading',
  ),
  SyncItemStatus.confirmed: _SyncStatusMeta(
    background: AppColors.successContainer,
    color: _confirmedColor,
    icon: Icons.check_circle,
    label: 'Confirmed',
  ),
  SyncItemStatus.failed: _SyncStatusMeta(
    background: AppColors.dangerContainer,
    color: AppColors.onDangerContainer,
    icon: Icons.error,
    label: 'Failed',
  ),
};

/// A single row in the sync queue: item name, status chip, and — depending
/// on status — a progress bar (uploading) or a Retry action (failed).
class SyncQueueItemTile extends StatelessWidget {
  const SyncQueueItemTile({
    super.key,
    required this.item,
    required this.onRetry,
  });

  final SyncItem item;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final meta = _kSyncStatusMeta[item.status]!;
    final isUploading = item.status == SyncItemStatus.uploading;
    final isFailed = item.status == SyncItemStatus.failed;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(meta: meta),
            ],
          ),
          if (isUploading) ...[
            const SizedBox(height: AppSpacing.sm),
            ThinProgressBar(progress: item.progress / 100),
          ],
          if (isFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            _RetryButton(onTap: onRetry),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.meta});

  final _SyncStatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.color),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: meta.color),
          ),
        ],
      ),
    );
  }
}

/// "Retry" is a bare 13px text link in the prototype; wrapped here in a
/// padded, 48x48dp-minimum tap target per DESIGN_SYSTEM.md §9 ("no
/// exceptions"), which makes a failed tile render slightly taller than the
/// prototype's literal spacing.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.centerLeft,
            child: Text(
              'Retry',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 13,
                color: AppColors.seed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
