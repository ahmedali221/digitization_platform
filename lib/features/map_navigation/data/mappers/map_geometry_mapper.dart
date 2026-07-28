import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:path/path.dart' as p;

import '../../../../core/data/models/floor_package_record.dart';
import '../../../../core/data/models/site_package_record.dart';
import '../../../../core/domain/entities/canvas_shape.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/package_asset_name.dart';
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

    final layers = <String, _CadLayer>{};
    for (final layer in (raw['layers'] as List? ?? const []).cast<Map>()) {
      final json = layer.cast<String, dynamic>();
      final name = json['name']?.toString();
      if (name == null || name.isEmpty) continue;
      layers[name] = _CadLayer(
        color: json['color']?.toString(),
        isVisible: json['is_visible'] != false,
      );
    }

    final cadShapes = <CadDrawingShape>[];
    final entities = (raw['geometry'] as List? ?? const []).cast<Map>();
    for (var index = 0; index < entities.length; index++) {
      final shape = _cadShapeFrom(
        entities[index].cast<String, dynamic>(),
        layers,
        index,
      );
      if (shape != null) cadShapes.add(shape);
    }

    final rooms = <FloorRoomGeometry>[];
    final wallLines = <String, WallLineShape>{};
    for (final room in (raw['rooms'] as List? ?? const []).cast<Map>()) {
      final roomJson = room.cast<String, dynamic>();
      final roomWallIds = <String>{};
      for (final wall in (roomJson['walls'] as List? ?? const []).cast<Map>()) {
        final wallJson = wall.cast<String, dynamic>();
        final wallId = wallJson['wall_id']?.toString();
        if (wallId == null) continue;
        roomWallIds.add(wallId);
        wallLines[wallId] = _lineFrom(wallJson);
      }
      rooms.add(
        FloorRoomGeometry(
          id: roomJson['id'].toString(),
          chamberId: roomJson['chamber_id']?.toString(),
          label: roomJson['label']?.toString() ?? 'Room ${rooms.length + 1}',
          rect: _rectFrom(roomJson),
          wallIds: roomWallIds,
        ),
      );
    }

    return FloorRoomsGeometry(
      canvas: _canvasFrom(canvasJson, floorRecord.siteId),
      cadShapes: cadShapes,
      rooms: rooms,
      wallLines: wallLines,
    );
  }

  CadDrawingShape? _cadShapeFrom(
    Map<String, dynamic> entity,
    Map<String, _CadLayer> layers,
    int index,
  ) {
    if (entity['is_visible'] == false) return null;

    final layerName = entity['layer']?.toString() ?? '0';
    final layer = layers[layerName];
    if (layer?.isVisible == false) return null;

    final geometry = (entity['geometry'] as Map?)?.cast<String, dynamic>();
    if (geometry == null) return null;

    final style = (entity['style'] as Map?)?.cast<String, dynamic>();
    final id = entity['id']?.toString() ?? 'cad_$index';
    final type = (entity['entity_type'] ?? geometry['kind'] ?? '')
        .toString()
        .toLowerCase();
    final colorValue = _cadColorValue(
      style?['color']?.toString() ?? layer?.color,
    );
    final strokeWidth = _number(style?['stroke_width']) ?? 1.5;

    if (type == 'circle') {
      final cx = _number(geometry['cx']);
      final cy = _number(geometry['cy']);
      final radius = _number(geometry['r']);
      if (cx == null || cy == null || radius == null || radius <= 0) {
        return null;
      }
      return CadCircleShape(
        id: id,
        colorValue: colorValue,
        strokeWidth: strokeWidth,
        center: Offset(cx, cy),
        radius: radius,
      );
    }

    if (type == 'point') {
      final x = _number(geometry['x']);
      final y = _number(geometry['y']);
      if (x == null || y == null) return null;
      return CadPointShape(id: id, colorValue: colorValue, point: Offset(x, y));
    }

    if (type == 'text' || type == 'mtext') {
      final x = _number(geometry['x']);
      final y = _number(geometry['y']);
      if (x == null || y == null) return null;
      return CadTextShape(
        id: id,
        colorValue: colorValue,
        point: Offset(x, y),
        text: geometry['text']?.toString() ?? entity['label']?.toString() ?? '',
        fontSize: _number(geometry['height']) ?? 12,
      );
    }

    final points = _renderPoints(geometry, type);
    if (points.length < 2) return null;
    return CadPathShape(
      id: id,
      colorValue: colorValue,
      strokeWidth: strokeWidth,
      points: points,
      closed: geometry['closed'] == true,
    );
  }

  List<Offset> _renderPoints(Map<String, dynamic> geometry, String type) {
    final renderPath = _pointsFrom(geometry['render_path']);
    if (renderPath.isNotEmpty) return renderPath;

    switch (geometry['kind']?.toString().toLowerCase() ?? type) {
      case 'line':
      case 'dimension':
        final x1 = _number(geometry['x1']);
        final y1 = _number(geometry['y1']);
        final x2 = _number(geometry['x2']);
        final y2 = _number(geometry['y2']);
        if (x1 == null || y1 == null || x2 == null || y2 == null) {
          return const [];
        }
        return [Offset(x1, y1), Offset(x2, y2)];
      case 'polyline':
      case 'lwpolyline':
      case 'spline':
      case 'solid':
      case 'trace':
      case 'hatch':
        return _pointsFrom(geometry['points']);
      case 'arc':
        return _sampleArc(geometry);
      case 'ellipse':
        return _sampleEllipse(geometry);
      default:
        return const [];
    }
  }

  List<Offset> _pointsFrom(Object? raw) {
    if (raw is! List || raw.isEmpty) return const [];

    final points = <Offset>[];
    if (raw.first is num) {
      for (var i = 0; i + 1 < raw.length; i += 2) {
        final x = _number(raw[i]);
        final y = _number(raw[i + 1]);
        if (x != null && y != null) points.add(Offset(x, y));
      }
      return points;
    }

    for (final value in raw) {
      if (value is Map) {
        final x = _number(value['x']);
        final y = _number(value['y']);
        if (x != null && y != null) points.add(Offset(x, y));
      } else if (value is List && value.length >= 2) {
        final x = _number(value[0]);
        final y = _number(value[1]);
        if (x != null && y != null) points.add(Offset(x, y));
      }
    }
    return points;
  }

  List<Offset> _sampleArc(Map<String, dynamic> geometry) {
    final cx = _number(geometry['cx']);
    final cy = _number(geometry['cy']);
    final radius = _number(geometry['r']);
    final start = _number(geometry['start_angle']) ?? 0;
    var end = _number(geometry['end_angle']) ?? math.pi * 2;
    if (cx == null || cy == null || radius == null) return const [];
    if (end < start) end += math.pi * 2;
    return List.generate(33, (index) {
      final angle = start + ((end - start) * index / 32);
      return Offset(
        cx + math.cos(angle) * radius,
        cy + math.sin(angle) * radius,
      );
    });
  }

  List<Offset> _sampleEllipse(Map<String, dynamic> geometry) {
    final cx = _number(geometry['cx']);
    final cy = _number(geometry['cy']);
    final majorX = _number(geometry['major_x']);
    final majorY = _number(geometry['major_y']);
    final ratio = _number(geometry['ratio']) ?? 1;
    if (cx == null || cy == null || majorX == null || majorY == null) {
      return const [];
    }
    final majorLength = math.sqrt((majorX * majorX) + (majorY * majorY));
    final rotation = math.atan2(majorY, majorX);
    return List.generate(37, (index) {
      final angle = math.pi * 2 * index / 36;
      final x = math.cos(angle) * majorLength;
      final y = math.sin(angle) * majorLength * ratio;
      return Offset(
        cx + (x * math.cos(rotation)) - (y * math.sin(rotation)),
        cy + (x * math.sin(rotation)) + (y * math.cos(rotation)),
      );
    });
  }

  double? _number(Object? value) => value is num ? value.toDouble() : null;

  int _cadColorValue(String? raw) {
    final hex = raw?.trim().replaceFirst('#', '') ?? '';
    final expanded = hex.length == 3
        ? hex.split('').map((value) => '$value$value').join()
        : hex;
    final rgb = expanded.length == 6 ? int.tryParse(expanded, radix: 16) : null;
    if (rgb == null) return 0xFF1F2937;

    final red = (rgb >> 16) & 0xFF;
    final green = (rgb >> 8) & 0xFF;
    final blue = rgb & 0xFF;
    final luminance =
        (0.2126 * red / 255) + (0.7152 * green / 255) + (0.0722 * blue / 255);

    // The mobile floor map uses a light workspace. Match the dashboard's
    // contrast guard so white/pale CAD strokes do not disappear.
    return luminance > 0.82 ? 0xFF1F2937 : 0xFF000000 | rgb;
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
    final fileName = packageImageFileName(url);
    final resolved = _directoryManager.packageImagePathSync(siteId, fileName);
    if (resolved != null) return resolved;

    // Keep already-downloaded packages usable until their next refresh. New
    // downloads always use the collision-safe name above.
    final legacyName = p.basename(Uri.parse(url).path);
    return _directoryManager.packageImagePathSync(siteId, legacyName);
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

class _CadLayer {
  const _CadLayer({required this.color, required this.isVisible});

  final String? color;
  final bool isVisible;
}
