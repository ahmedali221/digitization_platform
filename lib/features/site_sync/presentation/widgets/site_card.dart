import 'package:flutter/material.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/thin_progress_bar.dart';

/// One row on the sites list. Content branches on [SiteEntity.availability]:
/// not-downloaded shows a Download action, downloading shows progress, ready
/// shows the wall/sync summary — exactly one of the three ever renders since
/// those three states are mutually exclusive.
class SiteCard extends StatelessWidget {
  const SiteCard({
    super.key,
    required this.site,
    required this.onOpen,
    required this.onDownload,
  });

  final SiteEntity site;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TitleRow(site: site),
              const SizedBox(height: AppSpacing.md),
              if (site.isNotDownloaded)
                _NotDownloadedRow(onDownload: onDownload),
              if (site.isDownloading) _DownloadingRow(site: site),
              if (site.isReady) _ReadySummaryRow(site: site),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.site});

  final SiteEntity site;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                site.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                site.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
        if (site.isReady) ...[
          const SizedBox(width: AppSpacing.md),
          _ReadyBadges(site: site),
        ],
      ],
    );
  }
}

class _ReadyBadges extends StatelessWidget {
  const _ReadyBadges({required this.site});

  final SiteEntity site;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _Badge(
          icon: Icons.check_circle,
          label: 'Ready',
          background: AppColors.successContainer,
          foreground: AppColors.onSuccessContainer,
        ),
        if (site.updateAvailable) ...[
          const SizedBox(height: AppSpacing.xs),
          const _Badge(
            icon: Icons.sync,
            label: 'Update available',
            background: AppColors.warningContainer,
            foreground: AppColors.onWarningContainer,
            dense: true,
          ),
        ],
      ],
    );
  }
}

/// Local status pill for site-availability badges (Ready / Update available)
/// — distinct from `core/widgets/status_chip.dart`'s `StatusChip`, which is
/// keyed to `WallStatus` rather than an arbitrary icon/color pair.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : AppSpacing.sm,
        vertical: dense ? 3 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotDownloadedRow extends StatelessWidget {
  const _NotDownloadedRow({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 16, color: AppColors.iconMuted),
            const SizedBox(width: 6),
            Text(
              'Not downloaded',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ],
        ),
        _DownloadButton(onTap: onDownload),
      ],
    );
  }
}

/// Compact inline outlined button — deliberately not the shared full-width
/// `SecondaryActionButton` (DESIGN_SYSTEM.md's inventory has this as an
/// inline row action, not a full-width form action). The `SizedBox` enforces
/// the 48dp minimum touch target (DESIGN_SYSTEM.md §9) around the visually
/// compact pill.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.seed, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download, size: 16, color: AppColors.seed),
                  const SizedBox(width: 6),
                  Text(
                    'Download',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.seed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadingRow extends StatelessWidget {
  const _DownloadingRow({required this.site});

  final SiteEntity site;

  @override
  Widget build(BuildContext context) {
    final captionStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.onSurfaceMuted,
      fontSize: 13,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Downloading…', style: captionStyle),
            Text('${site.downloadProgress}%', style: captionStyle),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ThinProgressBar(progress: site.downloadProgress / 100),
      ],
    );
  }
}

class _ReadySummaryRow extends StatelessWidget {
  const _ReadySummaryRow({required this.site});

  final SiteEntity site;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '${site.wallsCaptured}/${site.wallsTotal} walls · Synced ${site.lastSynced}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ),
        const Icon(Icons.chevron_right, size: 20, color: AppColors.iconMuted),
      ],
    );
  }
}
