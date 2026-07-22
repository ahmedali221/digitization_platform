import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/building.dart';
import '../../../../core/domain/entities/floor.dart';
import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../../core/utils/canvas_layout.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/status_chip.dart';
import '../cubit/floors_cubit.dart';
import '../cubit/floors_state.dart';
import '../widgets/overview_metrics.dart';
import '../widgets/shape_canvas.dart';

/// The floor selection page: sits between a building and its walls,
/// listing the building's floors on an interactive canvas so the user picks
/// one to open (FLUTTER_MOBILE_PLAN.md §2's Level 1 map).
class FloorsListPage extends StatelessWidget {
  const FloorsListPage({
    super.key,
    required this.siteId,
    required this.buildingId,
  });

  final String siteId;
  final String buildingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          FloorsCubit(GetIt.instance<SiteRepository>(), siteId, buildingId),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<FloorsCubit, FloorsState>(
            builder: (context, state) {
              return switch (state) {
                FloorsLoading() => const LoadingIndicator(),
                FloorsNotFound() => ErrorRetryView(
                  message: 'This site could not be found.',
                  onRetry: () => context.safePop(),
                ),
                FloorsError(:final message) => ErrorRetryView(
                  message: message,
                  onRetry: () => context.safePop(),
                ),
                FloorsLoaded(:final site, :final building) =>
                  _FloorsListContent(site: site, building: building),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _FloorsListContent extends StatefulWidget {
  const _FloorsListContent({required this.site, required this.building});

  final SiteEntity site;
  final BuildingEntity building;

  @override
  State<_FloorsListContent> createState() => _FloorsListContentState();
}

class _FloorsListContentState extends State<_FloorsListContent> {
  /// Non-null while the legend's filter toggle is active — every floor whose
  /// aggregate status doesn't match is dimmed on the canvas
  /// (FLUTTER_MOBILE_PLAN.md §2's "filter toggle").
  WallStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final building = widget.building;
    final textTheme = Theme.of(context).textTheme;
    final filter = _filter;
    final dimmedFloorIds = filter == null
        ? const <String>{}
        : {
            for (final floor in building.floors)
              if (floor.aggregateStatus != filter) floor.id,
          };

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
                      label: site.name,
                      onTap: () => context.go('/sites/${site.id}/buildings'),
                    ),
                    BreadcrumbItem(label: building.name),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OverviewMetrics.horizontalPadding,
            0,
            OverviewMetrics.horizontalPadding,
            OverviewMetrics.subtitleBottomGap,
          ),
          child: Text(
            '${building.floors.length} floors · ${building.doneCount}/${building.wallCount} walls captured',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OverviewMetrics.horizontalPadding,
            0,
            OverviewMetrics.horizontalPadding,
            OverviewMetrics.legendBottomGap,
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in WallStatus.values)
                StatusLegendItem(
                  status: status,
                  selected: filter == status,
                  onTap: () => setState(
                    () => _filter = filter == status ? null : status,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: building.floors.isEmpty
              ? EmptyState(
                  icon: Icons.grid_view,
                  message: 'No floors yet for this building.',
                  actionLabel: 'Back to sites',
                  onAction: () => context.safePop(),
                )
              : _FloorCanvas(
                  floors: building.floors,
                  dimmedFloorIds: dimmedFloorIds,
                  onFloorTap: (floor) => context.push(
                    '/sites/$siteId/buildings/${building.id}/floors/${floor.id}',
                  ),
                ),
        ),
      ],
    );
  }

  String get siteId => widget.site.id;
}

/// The Level 1 map: floor shapes laid out and colored by aggregate wall
/// status, pinch-zoomable and pannable (FLUTTER_MOBILE_PLAN.md §2's canvas
/// renderer + hit-testing). Positions are auto-laid-out today since no
/// bundle has shipped designer-placed coordinates yet — see [CanvasLayout].
class _FloorCanvas extends StatelessWidget {
  const _FloorCanvas({
    required this.floors,
    required this.dimmedFloorIds,
    required this.onFloorTap,
  });

  final List<FloorEntity> floors;
  final Set<String> dimmedFloorIds;
  final ValueChanged<FloorEntity> onFloorTap;

  @override
  Widget build(BuildContext context) {
    final canvasSize = CanvasLayout.sizeFor(floors.length);
    final shapes = <CanvasShape>[
      for (var i = 0; i < floors.length; i++)
        CanvasRect(
          id: floors[i].id,
          color: floors[i].aggregateStatus.meta.color,
          label: floors[i].name,
          rect: CanvasLayout.rectFor(i, floors.length),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OverviewMetrics.horizontalPadding,
        0,
        OverviewMetrics.horizontalPadding,
        AppSpacing.xl,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.outlineSubtle),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ShapeCanvas(
            canvasSize: canvasSize,
            shapes: shapes,
            dimmedShapeIds: dimmedFloorIds,
            onShapeTap: (id) =>
                onFloorTap(floors.firstWhere((f) => f.id == id)),
          ),
        ),
      ),
    );
  }
}
