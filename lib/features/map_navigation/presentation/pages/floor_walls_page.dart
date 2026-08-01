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
import '../../domain/entities/map_geometry.dart';
import '../../domain/repositories/map_geometry_repository.dart';
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
        GetIt.instance<MapGeometryRepository>(),
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
                FloorWallsLoaded(
                  :final site,
                  :final building,
                  :final floor,
                  :final geometry,
                ) =>
                  _FloorWallsContent(
                    siteId: siteId,
                    siteName: site.name,
                    buildingId: building.id,
                    buildingName: building.name,
                    floorId: floorId,
                    floorName: floor.name,
                    walls: floor.walls,
                    geometry: geometry,
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _FloorWallsContent extends StatefulWidget {
  const _FloorWallsContent({
    required this.siteId,
    required this.siteName,
    required this.buildingId,
    required this.buildingName,
    required this.floorId,
    required this.floorName,
    required this.walls,
    required this.geometry,
  });

  final String siteId;
  final String siteName;
  final String buildingId;
  final String buildingName;
  final String floorId;
  final String floorName;
  final List<WallEntity> walls;
  final FloorRoomsGeometry? geometry;

  @override
  State<_FloorWallsContent> createState() => _FloorWallsContentState();
}

class _FloorWallsContentState extends State<_FloorWallsContent> {
  String? _selectedRoomId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roomFilters = _roomFilters(widget.geometry, widget.walls);
    final selectedRoom = _selectedRoom(roomFilters);
    final visibleWalls = selectedRoom == null
        ? widget.walls
        : widget.walls
              .where((wall) => selectedRoom.wallIds.contains(wall.id))
              .toList();
    final doneCount = visibleWalls
        .where(
          (w) => w.status == WallStatus.done || w.status == WallStatus.captured,
        )
        .length;
    final hasCanvasArtwork =
        widget.geometry != null &&
        (widget.geometry!.cadShapes.isNotEmpty ||
            widget.geometry!.rooms.isNotEmpty ||
            widget.geometry!.wallLines.isNotEmpty ||
            widget.geometry!.canvas.backgroundImagePath != null);

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
                      label: widget.siteName,
                      onTap: () =>
                          context.go('/sites/${widget.siteId}/buildings'),
                    ),
                    BreadcrumbItem(
                      label: widget.buildingName,
                      onTap: () => context.go(
                        '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors',
                      ),
                    ),
                    BreadcrumbItem(label: widget.floorName),
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
                      widget.floorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${selectedRoom?.label ?? 'All rooms'} · '
                      '$doneCount/${visibleWalls.length} walls captured',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _AddWallButton(
                onTap: () => context.push(
                  '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors/${widget.floorId}/add-wall',
                ),
              ),
            ],
          ),
        ),
        if (roomFilters.isNotEmpty)
          _RoomFilterBar(
            rooms: roomFilters,
            selectedRoomId: selectedRoom!.id,
            onSelected: (roomId) => setState(() => _selectedRoomId = roomId),
          ),
        Expanded(
          child: widget.walls.isEmpty && !hasCanvasArtwork
              ? EmptyState(
                  icon: Icons.grid_view,
                  message: 'No walls yet for this floor.',
                  actionLabel: 'Add wall',
                  onAction: () => context.push(
                    '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors/${widget.floorId}/add-wall',
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
                        walls: visibleWalls,
                        geometry: widget.geometry,
                        selectedRoomId: selectedRoom?.id,
                        onRoomTap: (roomId) =>
                            setState(() => _selectedRoomId = roomId),
                        onWallTap: (wall) => _openWallDetail(context, wall),
                      ),
                      if (visibleWalls.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            selectedRoom == null
                                ? 'Canvas loaded · no mapped walls yet'
                                : 'No walls in ${selectedRoom.label}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < visibleWalls.length; i++)
                        WallRow(
                          wall: visibleWalls[i],
                          isLast: i == visibleWalls.length - 1,
                          onTap: () =>
                              _openWallDetail(context, visibleWalls[i]),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _openWallDetail(BuildContext context, WallEntity wall) {
    final base =
        '/sites/${widget.siteId}/buildings/${widget.buildingId}/floors/${widget.floorId}';
    // Off-map (local_id) walls never enter grid-capture/sync-session —
    // that pipeline requires a real, server-known wall id (see
    // `UnassignedWallDetailPage`'s doc comment for why).
    context.push(
      wall.isLocal ? '$base/unassigned/${wall.id}' : '$base/walls/${wall.id}',
    );
  }

  _RoomFilter? _selectedRoom(List<_RoomFilter> rooms) {
    if (rooms.isEmpty) return null;
    return rooms.firstWhere(
      (room) => room.id == _selectedRoomId,
      orElse: () => rooms.first,
    );
  }
}

List<_RoomFilter> _roomFilters(
  FloorRoomsGeometry? geometry,
  List<WallEntity> walls,
) {
  final rooms = [
    for (final room in geometry?.rooms ?? const <FloorRoomGeometry>[])
      _RoomFilter(id: room.id, label: room.label, wallIds: room.wallIds),
  ];
  final assignedWallIds = rooms.expand((room) => room.wallIds).toSet();
  final unassignedWallIds = walls
      .where((wall) => !assignedWallIds.contains(wall.id))
      .map((wall) => wall.id)
      .toSet();

  if (rooms.isNotEmpty && unassignedWallIds.isNotEmpty) {
    rooms.add(
      _RoomFilter(
        id: _RoomFilter.unassignedId,
        label: 'Unassigned',
        wallIds: unassignedWallIds,
      ),
    );
  }
  return rooms;
}

class _RoomFilter {
  const _RoomFilter({
    required this.id,
    required this.label,
    required this.wallIds,
  });

  static const unassignedId = '_unassigned_walls';

  final String id;
  final String label;
  final Set<String> wallIds;
}

class _RoomFilterBar extends StatelessWidget {
  const _RoomFilterBar({
    required this.rooms,
    required this.selectedRoomId,
    required this.onSelected,
  });

  final List<_RoomFilter> rooms;
  final String selectedRoomId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OverviewMetrics.horizontalPadding,
        0,
        OverviewMetrics.horizontalPadding,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < rooms.length; index++) ...[
                  ChoiceChip(
                    key: ValueKey('room-filter-${rooms[index].id}'),
                    label: Text(rooms[index].label),
                    selected: rooms[index].id == selectedRoomId,
                    onSelected: (_) => onSelected(rooms[index].id),
                  ),
                  if (index != rooms.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
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

/// A tappable diagram of the floor's walls. Renders the bundle's real
/// dashboard-drawn rooms/walls (and background image) when [geometry] is
/// available — a real floor plan, pinch-zoomable like the buildings/floors
/// canvases above it in the hierarchy. Falls back to one fixed fake room
/// with walls evenly spaced around it (FLUTTER_MOBILE_PLAN.md §2's
/// hit-testing → wall tap_action) when it isn't.
class _WallLayoutDiagram extends StatelessWidget {
  const _WallLayoutDiagram({
    required this.walls,
    required this.geometry,
    required this.selectedRoomId,
    required this.onRoomTap,
    required this.onWallTap,
  });

  final List<WallEntity> walls;
  final FloorRoomsGeometry? geometry;
  final String? selectedRoomId;
  final ValueChanged<String> onRoomTap;
  final ValueChanged<WallEntity> onWallTap;

  static const _fallbackCanvasSize = CanvasSize(width: 300, height: 160);
  static const _fallbackRoomRect = RectShape(x: 16, y: 16, w: 268, h: 128);
  static const _roomOutlineId = '_room_outline';

  /// On-screen preview height once real geometry is in play — bigger than
  /// the fallback's fixed 160 since a real floor plan carries more detail,
  /// but still an embedded preview (not full-page) since this diagram sits
  /// above a scrollable wall list, not alone on its own screen.
  static const _geometryDisplayHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final geometry = this.geometry;
    if (walls.isEmpty && geometry == null) return const SizedBox.shrink();

    final CanvasSize canvasSize;
    final double displayHeight;
    final List<CanvasShape> shapes;

    if (geometry != null) {
      canvasSize = geometry.canvas;
      displayHeight = _geometryDisplayHeight;
      shapes = [
        for (final cadShape in geometry.cadShapes) _canvasShapeForCad(cadShape),
        for (final room in geometry.rooms)
          CanvasRect(
            id: '_room_${room.id}',
            label: room.label,
            color: room.id == selectedRoomId
                ? AppColors.seed
                : AppColors.outlineSubtle,
            rect: room.rect,
          ),
        for (final wall in walls)
          if (geometry.wallLines[wall.id] case final line?)
            CanvasLine(id: wall.id, color: wall.status.meta.color, line: line),
      ];
    } else {
      canvasSize = _fallbackCanvasSize;
      displayHeight = _fallbackCanvasSize.height;
      final wallLines = CanvasLayout.wallsAroundRoom(
        _fallbackRoomRect,
        walls.length,
      );
      shapes = [
        const CanvasRect(
          id: _roomOutlineId,
          color: AppColors.outlineSubtle,
          rect: _fallbackRoomRect,
          selectable: false,
        ),
        for (var i = 0; i < walls.length; i++)
          CanvasLine(
            id: walls[i].id,
            color: walls[i].status.meta.color,
            line: wallLines[i],
          ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: displayHeight,
            child: ShapeCanvas(
              canvasSize: canvasSize,
              shapes: shapes,
              interactive: geometry != null,
              fullscreenTitle: 'Walls map',
              onShapeTap: (id) {
                if (id.startsWith('_room_')) {
                  onRoomTap(id.substring('_room_'.length));
                  return;
                }
                onWallTap(walls.firstWhere((wall) => wall.id == id));
              },
            ),
          ),
        ),
      ),
    );
  }
}

CanvasShape _canvasShapeForCad(CadDrawingShape shape) {
  final color = Color(shape.colorValue);
  return switch (shape) {
    CadPathShape(:final id, :final points, :final strokeWidth, :final closed) =>
      CanvasPath(
        id: '_cad_$id',
        color: color,
        points: points,
        strokeWidth: strokeWidth,
        closed: closed,
      ),
    CadCircleShape(
      :final id,
      :final center,
      :final radius,
      :final strokeWidth,
    ) =>
      CanvasCircle(
        id: '_cad_$id',
        color: color,
        center: center,
        radius: radius,
        strokeWidth: strokeWidth,
      ),
    CadPointShape(:final id, :final point) => CanvasPoint(
      id: '_cad_$id',
      color: color,
      point: point,
    ),
    CadTextShape(:final id, :final point, :final text, :final fontSize) =>
      CanvasText(
        id: '_cad_$id',
        color: color,
        point: point,
        text: text,
        fontSize: fontSize,
      ),
  };
}
