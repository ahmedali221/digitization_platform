import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../../sync_queue/domain/repositories/sync_queue_repository.dart';
import '../cubit/wall_detail_cubit.dart';
import '../cubit/wall_detail_state.dart';
import '../widgets/overview_metrics.dart';

/// Wall-level page: thumbnail placeholder + status + last capture + notes,
/// and the single capture entry point (DESIGN_SYSTEM.md §7.2 — label swaps
/// "Start capture" / "Add more photos", the action itself is never disabled).
class WallDetailPage extends StatelessWidget {
  const WallDetailPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WallDetailCubit(
        GetIt.instance<SiteRepository>(),
        GetIt.instance<GridCaptureRepository>(),
        GetIt.instance<SyncQueueRepository>(),
        siteId,
        buildingId,
        floorId,
        wallId,
      ),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<WallDetailCubit, WallDetailState>(
            builder: (context, state) {
              return switch (state) {
                WallDetailLoading() => const LoadingIndicator(),
                WallDetailNotFound() => ErrorRetryView(
                  message: 'This wall could not be found.',
                  onRetry: () => context.safePop(),
                ),
                WallDetailError(:final message) => ErrorRetryView(
                  message: message,
                  onRetry: () => context.safePop(),
                ),
                WallDetailLoaded(
                  :final site,
                  :final buildingName,
                  :final floorName,
                  :final wall,
                ) =>
                  _WallDetailContent(
                    siteId: siteId,
                    siteName: site.name,
                    buildingId: buildingId,
                    buildingName: buildingName,
                    floorId: floorId,
                    floorName: floorName,
                    wall: wall,
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _WallDetailContent extends StatelessWidget {
  const _WallDetailContent({
    required this.siteId,
    required this.siteName,
    required this.buildingId,
    required this.buildingName,
    required this.floorId,
    required this.floorName,
    required this.wall,
  });

  final String siteId;
  final String siteName;
  final String buildingId;
  final String buildingName;
  final String floorId;
  final String floorName;
  final WallEntity wall;

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
                      label: siteName,
                      onTap: () => context.go('/sites/$siteId/buildings'),
                    ),
                    BreadcrumbItem(
                      label: buildingName,
                      onTap: () => context.go(
                        '/sites/$siteId/buildings/$buildingId/floors',
                      ),
                    ),
                    BreadcrumbItem(
                      label: floorName,
                      onTap: () => context.go(
                        '/sites/$siteId/buildings/$buildingId/floors/$floorId',
                      ),
                    ),
                    BreadcrumbItem(label: wall.name),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              OverviewMetrics.horizontalPadding,
              AppSpacing.sm,
              OverviewMetrics.horizontalPadding,
              OverviewMetrics.wallSheetBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wall.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.outlineSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image,
                        size: 26,
                        color: AppColors.iconMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusChip(status: wall.status),
                          const SizedBox(height: 6),
                          Text(
                            'Last capture: ${wall.lastCapture}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  Text(
                    wall.notes,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryActionButton(
                  label: wall.hasGrid ? 'Add more photos' : 'Start capture',
                  onTap: () => _onCapture(context),
                ),
                if ((wall.grid?.filledCount ?? 0) > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryActionButton(
                    label: 'Upload to dashboard',
                    icon: Icons.cloud_upload_outlined,
                    onTap: () => _onUpload(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onCapture(BuildContext context) {
    final base =
        '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/${wall.id}';
    context.push(wall.hasGrid ? '$base/grid-capture' : '$base/grid-init');
  }

  Future<void> _onUpload(BuildContext context) async {
    final cubit = context.read<WallDetailCubit>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await cubit.uploadToDashboard();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (success) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.seed,
            size: 40,
          ),
          title: const Text('Upload complete'),
          content: const Text(
            "This wall's photos were uploaded to the dashboard.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed — check the Sync Queue for details.'),
        ),
      );
    }
  }
}
