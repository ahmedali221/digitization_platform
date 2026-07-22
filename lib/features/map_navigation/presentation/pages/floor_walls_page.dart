import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/canvas_shape.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../../core/utils/canvas_layout.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/breadcrumb.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../cubit/floor_walls_cubit.dart';
import '../cubit/floor_walls_state.dart';
import '../widgets/overview_metrics.dart';
import '../widgets/shape_canvas.dart';
import '../widgets/wall_row.dart';

/// Floor-level page: lists a floor's walls, with an "Add wall" action and a
/// tap-to-open entry point into each wall's detail page — the walls tab
/// between a building's floor selection and an individual wall.
class FloorWallsPage extends StatelessWidget {
  const FloorWallsPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FloorWallsCubit(
        GetIt.instance<SiteRepository>(),
        siteId,
        buildingId,
        floorId,
      ),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<FloorWallsCubit, FloorWallsState>(
            builder: (context, state) {
              return switch (state) {
                FloorWallsLoading() => const LoadingIndicator(),
                FloorWallsNotFound() => ErrorRetryView(
                  message: 'This floor could not be found.',
                  onRetry: () => context.safePop(),
                ),
                FloorWallsError(:final message) => ErrorRetryView(
                  message: message,
                  onRetry: () => context.safePop(),
                ),
                FloorWallsLoaded(:final site, :final building, :final floor) =>
                  _FloorWallsContent(
                    siteId: siteId,
                    siteName: site.name,
                    buildingId: building.id,
                    buildingName: building.name,
                    floorId: floorId,
                    floorName: floor.name,
                    walls: floor.walls,
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _FloorWallsContent extends StatelessWidget {
  const _FloorWallsContent({
    required this.siteId,
    required this.siteName,
    required this.buildingId,
    required this.buildingName,
    required this.floorId,
    required this.floorName,
    required this.walls,
  });

  final String siteId;
  final String siteName;
  final String buildingId;
  final String buildingName;
  final String floorId;
  final String floorName;
  final List<WallEntity> walls;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final doneCount = walls
        .where(
          (w) => w.status == WallStatus.done || w.status == WallStatus.captured,
        )
        .length;

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
                    BreadcrumbItem(label: floorName),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      floorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$doneCount/${walls.length} walls · tap a wall to open',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AddWallButton(
                onTap: () => context.push(
                  '/sites/$siteId/buildings/$buildingId/floors/$floorId/add-wall',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: walls.isEmpty
              ? EmptyState(
                  icon: Icons.grid_view,
                  message: 'No walls yet for this floor.',
                  actionLabel: 'Add wall',
                  onAction: () => context.push(
                    '/sites/$siteId/buildings/$buildingId/floors/$floorId/add-wall',
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    OverviewMetrics.horizontalPadding,
                    0,
                    OverviewMetrics.horizontalPadding,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      _WallLayoutDiagram(
                        walls: walls,
                        onWallTap: (wall) => _openWallDetail(context, wall),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < walls.length; i++)
                        WallRow(
                          wall: walls[i],
                          isLast: i == walls.length - 1,
                          onTap: () => _openWallDetail(context, walls[i]),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _openWallDetail(BuildContext context, WallEntity wall) {
    context.push(
      '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/${wall.id}',
    );
  }
}

class _AddWallButton extends StatelessWidget {
  const _AddWallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.seed,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, tappable diagram of the floor's walls arranged around its
/// perimeter (FLUTTER_MOBILE_PLAN.md §2's hit-testing → wall tap_action,
/// applied one level down from the site canvas).
class _WallLayoutDiagram extends StatelessWidget {
  const _WallLayoutDiagram({required this.walls, required this.onWallTap});

  final List<WallEntity> walls;
  final ValueChanged<WallEntity> onWallTap;

  static const _canvasSize = CanvasSize(width: 300, height: 160);
  static const _roomRect = RectShape(x: 16, y: 16, w: 268, h: 128);
  static const _roomOutlineId = '_room_outline';

  @override
  Widget build(BuildContext context) {
    if (walls.isEmpty) return const SizedBox.shrink();
    final wallLines = CanvasLayout.wallsAroundRoom(_roomRect, walls.length);
    final shapes = <CanvasShape>[
      const CanvasRect(
        id: _roomOutlineId,
        color: AppColors.outlineSubtle,
        rect: _roomRect,
      ),
      for (var i = 0; i < walls.length; i++)
        CanvasLine(
          id: walls[i].id,
          color: walls[i].status.meta.color,
          line: wallLines[i],
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: SizedBox(
          height: _canvasSize.height,
          child: ShapeCanvas(
            canvasSize: _canvasSize,
            shapes: shapes,
            interactive: false,
            onShapeTap: (id) {
              if (id == _roomOutlineId) return;
              onWallTap(walls.firstWhere((w) => w.id == id));
            },
          ),
        ),
      ),
    );
  }
}
