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

/// Real, dashboard-drawn positions for one floor's rooms and walls.
/// [roomRects] are a non-interactive backdrop (drawn behind the walls, never
/// tappable); [wallLines] are keyed by wall id, matching `WallEntity.id`. A
/// wall with no entry here (e.g. one added via the on-device "Add wall" flow)
/// simply isn't drawn — it still appears in the scrollable wall list.
class FloorRoomsGeometry extends Equatable {
  const FloorRoomsGeometry({
    required this.canvas,
    required this.cadShapes,
    required this.roomRects,
    required this.wallLines,
  });

  final CanvasSize canvas;
  final List<CadDrawingShape> cadShapes;
  final List<RectShape> roomRects;
  final Map<String, WallLineShape> wallLines;

  @override
  List<Object?> get props => [canvas, cadShapes, roomRects, wallLines];
}
