import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/entities/unassigned_wall.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import '../cubit/unassigned_wall_detail_cubit.dart';
import '../cubit/unassigned_wall_detail_state.dart';

/// Detail/action screen for one off-map wall: capture flat photos, register
/// its metadata (`POST /sync/unassigned`), and once a dashboard operator has
/// resolved it to a real wall, hand the photos off to the normal
/// grid-capture/sync-queue pipeline. Reached from `FloorWallsPage` when the
/// tapped wall is `WallEntity.isLocal` — never from `WallDetailPage`.
class UnassignedWallDetailPage extends StatelessWidget {
  const UnassignedWallDetailPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.localId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String localId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UnassignedWallDetailCubit(
        GetIt.instance<UnassignedWallRepository>(),
        localId,
      ),
      child: Scaffold(
        body: SafeArea(
          child:
              BlocBuilder<UnassignedWallDetailCubit, UnassignedWallDetailState>(
                builder: (context, state) {
                  return switch (state) {
                    UnassignedWallDetailLoading() => const LoadingIndicator(),
                    UnassignedWallDetailNotFound() => ErrorRetryView(
                      message: 'This unassigned wall could not be found.',
                      onRetry: () => context.safePop(),
                    ),
                    UnassignedWallDetailError(:final message) => ErrorRetryView(
                      message: message,
                      onRetry: () => context.safePop(),
                    ),
                    UnassignedWallDetailLoaded(:final wall, :final syncing) =>
                      _Content(
                        siteId: siteId,
                        buildingId: buildingId,
                        floorId: floorId,
                        wall: wall,
                        syncing: syncing,
                      ),
                  };
                },
              ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wall,
    required this.syncing,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final UnassignedWall wall;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                onTap: () => context.safePop(),
                visualDiameter: 40,
                iconSize: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Breadcrumb(
                  items: [
                    BreadcrumbItem(
                      label: 'Sites',
                      onTap: () => context.go('/sites'),
                    ),
                    BreadcrumbItem(
                      label: 'Unassigned',
                      onTap: () => context.go('/unassigned'),
                    ),
                    BreadcrumbItem(label: wall.title),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              AppSpacing.sm,
              20,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wall.title,
                  style: textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  wall.localId,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SyncStatusBadge(wall: wall),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${wall.photoCount} photos captured',
                  style: textTheme.bodyMedium,
                ),
                if (wall.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'NOTES',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(wall.notes, style: textTheme.bodyMedium),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No note added yet — add one before this can be '
                    'resolved on the dashboard.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryActionButton(
                  label: wall.photoCount > 0
                      ? 'Add more photos'
                      : 'Start capture',
                  onTap: () => context.push(
                    '/sites/$siteId/buildings/$buildingId/floors/$floorId'
                    '/unassigned/${wall.localId}/camera',
                  ),
                ),
                if (wall.syncStatus != UnassignedWallSyncStatus.resolved &&
                    wall.photoCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryActionButton(
                    label: 'Sync to dashboard',
                    icon: Icons.cloud_upload_outlined,
                    onTap: syncing ? () {} : () => _onSync(context),
                  ),
                ],
                if (wall.syncStatus == UnassignedWallSyncStatus.resolved) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Resolved to wall ${wall.resolvedWallId}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryActionButton(
                    label: 'Upload photos',
                    icon: Icons.cloud_upload_outlined,
                    onTap: syncing ? () {} : () => _onUpload(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSync(BuildContext context) async {
    final cubit = context.read<UnassignedWallDetailCubit>();
    final success = await cubit.syncToDashboard();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Synced — waiting for a dashboard operator to resolve it.'
              : 'Sync failed — check your connection and try again.',
        ),
      ),
    );
  }

  Future<void> _onUpload(BuildContext context) async {
    final cubit = context.read<UnassignedWallDetailCubit>();
    final success = await cubit.uploadPhotos();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Photos queued for upload — check the Sync Queue for progress.'
              : 'Could not start the upload — try again.',
        ),
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.wall});

  final UnassignedWall wall;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (wall.syncStatus) {
      UnassignedWallSyncStatus.notSynced => (
        'Not synced',
        AppColors.onSurfaceMuted,
      ),
      UnassignedWallSyncStatus.awaitingResolution => (
        'Awaiting resolution',
        AppColors.seed,
      ),
      UnassignedWallSyncStatus.resolved => ('Resolved', AppColors.seed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.hoverSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
