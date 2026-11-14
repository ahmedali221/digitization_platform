import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../../object_capture/domain/repositories/object_capture_repository.dart';
import '../../../sync_queue/domain/repositories/sync_queue_repository.dart';
import '../cubit/wall_detail_cubit.dart';
import '../cubit/wall_detail_state.dart';
import '../widgets/form_field_label.dart';
import '../widgets/item_sync_chip.dart';
import '../widgets/object_metadata_summary.dart';
import '../widgets/overview_metrics.dart';

/// The page of one wall or object: what it is, where it stands, and the
/// single capture entry point (DESIGN_SYSTEM.md §7.2 — label swaps
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
        GetIt.instance<ObjectCaptureRepository>(),
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
                  message: 'This item could not be found.',
                  onRetry: () => context.safePop(),
                ),
                WallDetailError(:final message) => ErrorRetryView(
                  message: message,
                  onRetry: () => context.safePop(),
                ),
                WallDetailLoaded() => _WallDetailContent(
                  siteId: siteId,
                  buildingId: buildingId,
                  floorId: floorId,
                  state: state,
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
    required this.buildingId,
    required this.floorId,
    required this.state,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final WallDetailLoaded state;

  String get _floorPath =>
      '/sites/$siteId/buildings/$buildingId/floors/$floorId';

  @override
  Widget build(BuildContext context) {
    final wall = state.wall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WallBreadcrumb(
          siteId: siteId,
          buildingId: buildingId,
          floorPath: _floorPath,
          state: state,
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
                Text(wall.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                _WallSummary(wall: wall),
                if (!wall.metadata.isEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ObjectMetadataSummary(metadata: wall.metadata),
                ],
                if (wall.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const FormFieldLabel('Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    wall.notes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryActionButton(
                  label: state.hasStartedCapture
                      ? 'Add more photos'
                      : 'Start capture',
                  onTap: () => _onCapture(context),
                ),
                if (state.hasLocalPhotos) ...[
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
    final wall = state.wall;
    final base = '$_floorPath/walls/${wall.id}';
    final segment = switch (wall.captureMode) {
      CaptureMode.loose => 'object-capture',
      CaptureMode.grid => wall.hasGrid ? 'grid-capture' : 'grid-init',
    };
    context.push('$base/$segment');
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
          icon: const Icon(Icons.check_circle, color: AppColors.seed, size: 40),
          title: const Text('Upload complete'),
          content: const Text('Its photos were uploaded to the dashboard.'),
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

class _WallBreadcrumb extends StatelessWidget {
  const _WallBreadcrumb({
    required this.siteId,
    required this.buildingId,
    required this.floorPath,
    required this.state,
  });

  static const double _backButtonDiameter = 40;
  static const double _backIconSize = 22;

  final String siteId;
  final String buildingId;
  final String floorPath;
  final WallDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            visualDiameter: _backButtonDiameter,
            iconSize: _backIconSize,
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
                  label: state.site.name,
                  onTap: () => context.go('/sites/$siteId/buildings'),
                ),
                BreadcrumbItem(
                  label: state.buildingName,
                  onTap: () =>
                      context.go('/sites/$siteId/buildings/$buildingId/floors'),
                ),
                BreadcrumbItem(
                  label: state.floorName,
                  onTap: () => context.go(floorPath),
                ),
                BreadcrumbItem(label: state.wall.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the record is and where it stands: its type, its capture status,
/// when it was last photographed, and — for one added on this phone or
/// waiting for review — that too.
class _WallSummary extends StatelessWidget {
  const _WallSummary({required this.wall});

  static const double _emblemExtent = 56;
  static const double _emblemIconSize = 26;

  final WallEntity wall;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _emblemExtent,
          height: _emblemExtent,
          decoration: BoxDecoration(
            color: AppColors.outlineSubtle,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(
            wall.objectType.meta.icon,
            size: _emblemIconSize,
            color: AppColors.iconMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(status: wall.status),
                  ItemSyncChip(wall: wall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  wall.objectType.meta.label,
                  wall.roomLabel,
                  'Last capture: ${wall.lastCapture}',
                ].nonNulls.join(' · '),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
