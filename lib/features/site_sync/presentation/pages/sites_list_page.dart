import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/network/connectivity_observer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../cubit/sites_cubit.dart';
import '../cubit/sites_state.dart';
import '../widgets/download_confirm_dialog.dart';
import '../widgets/site_card.dart';
import '../widgets/sync_status_icon.dart';

/// The app's initial/home route (`/sites`). Its own `Scaffold` is the only
/// app-level chrome this screen has — no bottom nav bar here.
class SitesListPage extends StatelessWidget {
  const SitesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SitesCubit(
        GetIt.instance<SiteRepository>(),
        GetIt.instance<ConnectivityObserver>(),
      ),
      child: const Scaffold(body: SafeArea(child: _SitesListBody())),
    );
  }
}

class _SitesListBody extends StatefulWidget {
  const _SitesListBody();

  @override
  State<_SitesListBody> createState() => _SitesListBodyState();
}

class _SitesListBodyState extends State<_SitesListBody> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SitesCubit, SitesState>(
      builder: (context, state) {
        final isOffline = state is SitesLoaded && state.isOffline;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(isOffline: isOffline)),
            if (isOffline) const SliverToBoxAdapter(child: OfflineBanner()),
            if (state is SitesLoaded)
              SliverToBoxAdapter(
                child: _ArchiveTabBar(
                  showArchived: _showArchived,
                  activeCount: state.activeSites.length,
                  archivedCount: state.archivedSites.length,
                  onChanged: (showArchived) =>
                      setState(() => _showArchived = showArchived),
                ),
              ),
            ..._contentSlivers(context, state),
          ],
        );
      },
    );
  }

  List<Widget> _contentSlivers(BuildContext context, SitesState state) {
    switch (state) {
      case SitesLoading():
        return const [
          SliverFillRemaining(hasScrollBody: false, child: LoadingIndicator()),
        ];
      case SitesError(:final message):
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorRetryView(
              message: message,
              onRetry: () => context.read<SitesCubit>().retry(),
            ),
          ),
        ];
      case SitesLoaded():
        final sites = _showArchived ? state.archivedSites : state.activeSites;
        if (sites.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: _showArchived
                    ? Icons.archive_outlined
                    : Icons.location_on_outlined,
                message: _showArchived
                    ? 'No archived sites'
                    : 'No sites yet — prepare a site from the web dashboard to get started',
              ),
            ),
          ];
        }
        return [
          if (!_showArchived)
            SliverToBoxAdapter(child: _ReadyCountLabel(sites: sites)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              _showArchived ? AppSpacing.md : AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index.isOdd) return const SizedBox(height: AppSpacing.md);
                final site = sites[index ~/ 2];
                return SiteCard(
                  site: site,
                  onOpen: site.isReady
                      ? () => context.push('/sites/${site.id}/buildings')
                      : () {},
                  onDownload: () =>
                      _confirmAndDownload(context, site.id, site.name),
                  onArchiveToggle: () => site.isArchived
                      ? context.read<SitesCubit>().unarchiveSite(site.id)
                      : context.read<SitesCubit>().archiveSite(site.id),
                );
              }, childCount: sites.length * 2 - 1),
            ),
          ),
        ];
    }
  }

  Future<void> _confirmAndDownload(
    BuildContext context,
    String siteId,
    String siteName,
  ) async {
    final cubit = context.read<SitesCubit>();
    final confirmed = await showDownloadConfirmDialog(
      context: context,
      siteName: siteName,
      loadEstimate: () => cubit.estimateDownload(siteId),
    );
    if (confirmed == true) {
      await cubit.startDownload(siteId);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + AppSpacing.xs,
        AppSpacing.lg + AppSpacing.xs,
        AppSpacing.lg + AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Sites', style: Theme.of(context).textTheme.titleLarge),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SyncStatusIcon(onTap: () => context.push('/sync')),
              CircleIconButton(
                icon: Icons.assignment,
                onTap: () => context.push('/unassigned'),
              ),
              CircleIconButton(
                icon: Icons.logout,
                onTap: () => _confirmLogout(context),
              ),
              if (isOffline) ...[
                const SizedBox(width: AppSpacing.xs),
                const OfflinePill(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Clears the stored session token, which flips [isLoggedInNotifier] to
/// false — the router's own `refreshListenable` on that notifier then
/// redirects to `/login` on its own, no explicit navigation needed here.
Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        "You'll need your email and password to sign back in.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await GetIt.instance<AuthRepository>().logout();
  }
}

class _ReadyCountLabel extends StatelessWidget {
  const _ReadyCountLabel({required this.sites});

  final List<SiteEntity> sites;

  @override
  Widget build(BuildContext context) {
    final readyCount = sites.where((site) => site.isReady).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        '$readyCount of ${sites.length} sites ready for field',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
      ),
    );
  }
}

/// Two-segment "Sites" / "Archived" toggle. No `TabBar` pattern exists
/// elsewhere in this app (every list here is a flat page), so this follows
/// the same hand-rolled `Material`+`InkWell` pill style as `SiteCard`'s
/// badges rather than pulling in Flutter's default tab chrome.
class _ArchiveTabBar extends StatelessWidget {
  const _ArchiveTabBar({
    required this.showArchived,
    required this.activeCount,
    required this.archivedCount,
    required this.onChanged,
  });

  final bool showArchived;
  final int activeCount;
  final int archivedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Sites',
                count: activeCount,
                selected: !showArchived,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Archived',
                count: archivedCount,
                selected: showArchived,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.chip - 2),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Center(
            child: Text(
              '$label ($count)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.seed : AppColors.onSurfaceMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
