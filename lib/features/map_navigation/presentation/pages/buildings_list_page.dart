import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/building.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../../core/utils/canvas_layout.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../domain/entities/map_geometry.dart';
import '../../domain/repositories/map_geometry_repository.dart';
import '../cubit/buildings_cubit.dart';
import '../cubit/buildings_state.dart';
import '../widgets/overview_metrics.dart';
import '../widgets/shape_canvas.dart';

/// First hierarchy level below a site. Selecting a building opens its floors;
/// it never opens walls directly.
class BuildingsListPage extends StatelessWidget {
  const BuildingsListPage({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BuildingsCubit(
        GetIt.instance<SiteRepository>(),
        GetIt.instance<MapGeometryRepository>(),
        siteId,
      ),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<BuildingsCubit, BuildingsState>(
            builder: (context, state) => switch (state) {
              BuildingsLoading() => const LoadingIndicator(),
              BuildingsNotFound() => ErrorRetryView(
                message: 'This site could not be found.',
                onRetry: () => context.safePop(),
              ),
              BuildingsError(:final message) => ErrorRetryView(
                message: message,
                onRetry: () => context.safePop(),
              ),
              BuildingsLoaded(:final site, :final geometry) => Column(
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
                              BreadcrumbItem(label: site.name),
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
                      '${site.buildings.length} buildings · ${site.wallsCaptured}/${site.wallsTotal} walls captured',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: site.buildings.isEmpty
                        ? EmptyState(
                            icon: Icons.apartment,
                            message: 'No buildings yet for this site.',
                            actionLabel: 'Back to sites',
                            onAction: () => context.safePop(),
                          )
                        : _BuildingCanvas(
                            buildings: site.buildings,
                            geometry: geometry,
                            onBuildingTap: (building) => context.push(
                              '/sites/$siteId/buildings/${building.id}/floors',
                            ),
                          ),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _BuildingCanvas extends StatelessWidget {
  const _BuildingCanvas({
    required this.buildings,
    required this.geometry,
    required this.onBuildingTap,
  });

  final List<BuildingEntity> buildings;
  final SiteOverviewGeometry? geometry;
  final ValueChanged<BuildingEntity> onBuildingTap;

  @override
  Widget build(BuildContext context) {
    final canvasSize = geometry?.canvas ?? CanvasLayout.sizeFor(buildings.length);
    final shapes = <CanvasShape>[
      for (var index = 0; index < buildings.length; index++)
        CanvasRect(
          id: buildings[index].id,
          color: buildings[index].aggregateStatus.meta.color,
          label: buildings[index].name,
          rect:
              geometry?.buildingRects[buildings[index].id] ??
              CanvasLayout.rectFor(index, buildings.length),
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
            fullscreenTitle: 'Buildings map',
            onShapeTap: (id) => onBuildingTap(
              buildings.firstWhere((building) => building.id == id),
            ),
          ),
        ),
      ),
    );
  }
}
