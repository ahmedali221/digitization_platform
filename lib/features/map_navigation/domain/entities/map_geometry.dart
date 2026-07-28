import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/canvas_shape.dart';

/// Real, dashboard-drawn positions for a site's buildings on its overview
/// canvas, keyed by building id. Null wherever a bundle carries no manually
/// drawn geometry — callers fall back to `CanvasLayout`'s auto-grid.
class SiteOverviewGeometry extends Equatable {
  const SiteOverviewGeometry({
    required this.canvas,
    required this.buildingRects,
  });

  final CanvasSize canvas;
  final Map<String, RectShape> buildingRects;

  @override
  List<Object?> get props => [canvas, buildingRects];
}

/// Real, dashboard-drawn positions for one building's floors, keyed by
/// floor id.
class BuildingFloorsGeometry extends Equatable {
  const BuildingFloorsGeometry({
    required this.canvas,
    required this.floorRects,
  });

  final CanvasSize canvas;
  final Map<String, RectShape> floorRects;

  @override
  List<Object?> get props => [canvas, floorRects];
}

/// One selectable room and the ids of the walls nested under it in the
/// published floor package.
class FloorRoomGeometry extends Equatable {
  const FloorRoomGeometry({
    required this.id,
    required this.label,
    required this.rect,
    required this.wallIds,
    this.chamberId,
  });

  final String id;
  final String? chamberId;
  final String label;
  final RectShape rect;
  final Set<String> wallIds;

  @override
  List<Object?> get props => [id, chamberId, label, rect, wallIds];
}

/// Real, dashboard-drawn positions for one floor's rooms and walls. Retaining
/// the room-to-wall relationship lets the floor view show only the selected
/// room's walls. [wallLines] are keyed by `WallEntity.id`.
class FloorRoomsGeometry extends Equatable {
  const FloorRoomsGeometry({
    required this.canvas,
    required this.cadShapes,
    required this.rooms,
    required this.wallLines,
  });

  final CanvasSize canvas;
  final List<CadDrawingShape> cadShapes;
  final List<FloorRoomGeometry> rooms;
  final Map<String, WallLineShape> wallLines;

  /// Kept as a convenience for callers that only need room outlines.
  List<RectShape> get roomRects => rooms.map((room) => room.rect).toList();

  @override
  List<Object?> get props => [canvas, cadShapes, rooms, wallLines];
}
