import 'package:path/path.dart' as p;

import '../../../../core/data/models/floor_package_record.dart';
import '../../../../core/data/models/site_package_record.dart';
import '../../../../core/domain/entities/canvas_shape.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../domain/entities/map_geometry.dart';

/// Pure JSON-walking over the same raw bundle JSON the site mapper already
/// reads — just the position fields (x/y/w/h/canvas) instead of the
/// identity/status fields it maps. The one exception to "pure": resolving a
/// background image asks the directory manager whether the file actually
/// landed on disk, so a canvas is never pointed at an image that isn't there.
class MapGeometryMapper {
  const MapGeometryMapper(this._directoryManager);

  final DirectoryManager _directoryManager;

  SiteOverviewGeometry? overviewGeometryFor(SitePackageRecord siteRecord) {
    final raw = siteRecord.raw;
    if (raw == null) return null;
    final overviewCanvas = (raw['overview_canvas'] as Map?)
        ?.cast<String, dynamic>();
    if (overviewCanvas == null) return null;

    final buildingRects = <String, RectShape>{};
    for (final building in (raw['buildings'] as List).cast<Map>()) {
      final buildingJson = building.cast<String, dynamic>();
      final shape = (buildingJson['shape'] as Map?)?.cast<String, dynamic>();
      if (shape == null) continue;
      buildingRects[buildingJson['id'].toString()] = _rectFrom(shape);
    }

    return SiteOverviewGeometry(
      canvas: _canvasFrom(overviewCanvas, siteRecord.siteId),
      buildingRects: buildingRects,
    );
  }

  BuildingFloorsGeometry? floorsGeometryFor(
    SitePackageRecord siteRecord,
    String buildingId,
  ) {
    final raw = siteRecord.raw;
    if (raw == null) return null;

    for (final building in (raw['buildings'] as List).cast<Map>()) {
      final buildingJson = building.cast<String, dynamic>();
      if (buildingJson['id'].toString() != buildingId) continue;

      final buildingCanvas = (buildingJson['building_canvas'] as Map?)
          ?.cast<String, dynamic>();
      if (buildingCanvas == null) return null;

      final floorRects = <String, RectShape>{};
      for (final shape
          in (buildingCanvas['shapes'] as List? ?? const []).cast<Map>()) {
        final shapeJson = shape.cast<String, dynamic>();
        floorRects[shapeJson['floor_id'].toString()] = _rectFrom(shapeJson);
      }

      return BuildingFloorsGeometry(
        canvas: _canvasFrom(buildingCanvas, siteRecord.siteId),
        floorRects: floorRects,
      );
    }
    return null;
  }

  FloorRoomsGeometry? roomsGeometryFor(FloorPackageRecord floorRecord) {
    final raw = floorRecord.raw;
    final canvasJson = (raw['canvas'] as Map?)?.cast<String, dynamic>();
    if (canvasJson == null) return null;

    final roomRects = <RectShape>[];
    final wallLines = <String, WallLineShape>{};
    for (final room in (raw['rooms'] as List? ?? const []).cast<Map>()) {
      final roomJson = room.cast<String, dynamic>();
      roomRects.add(_rectFrom(roomJson));
      for (final wall in (roomJson['walls'] as List? ?? const []).cast<Map>()) {
        final wallJson = wall.cast<String, dynamic>();
        final wallId = wallJson['wall_id']?.toString();
        if (wallId == null) continue;
        wallLines[wallId] = _lineFrom(wallJson);
      }
    }

    return FloorRoomsGeometry(
      canvas: _canvasFrom(canvasJson, floorRecord.siteId),
      roomRects: roomRects,
      wallLines: wallLines,
    );
  }

  CanvasSize _canvasFrom(Map<String, dynamic> canvasJson, String siteId) {
    return CanvasSize(
      width: (canvasJson['width'] as num).toDouble(),
      height: (canvasJson['height'] as num).toDouble(),
      backgroundImagePath: _resolveImagePath(
        siteId,
        canvasJson['background_image_url'] as String?,
      ),
    );
  }

  String? _resolveImagePath(String siteId, String? url) {
    if (url == null || url.isEmpty) return null;
    final fileName = p.basename(Uri.parse(url).path);
    return _directoryManager.packageImagePathSync(siteId, fileName);
  }

  RectShape _rectFrom(Map<String, dynamic> json) => RectShape(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );

  WallLineShape _lineFrom(Map<String, dynamic> json) => WallLineShape(
    x1: (json['x1'] as num).toDouble(),
    y1: (json['y1'] as num).toDouble(),
    x2: (json['x2'] as num).toDouble(),
    y2: (json['y2'] as num).toDouble(),
  );
}
