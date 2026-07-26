import 'package:digitization_platform/core/data/models/floor_package_record.dart';
import 'package:digitization_platform/core/domain/entities/canvas_shape.dart';
import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/features/map_navigation/data/mappers/map_geometry_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the published CAD canvas with layer visibility and styles', () {
    final record = FloorPackageRecord(
      floorId: '7',
      siteId: '1',
      downloadedAt: DateTime(2026),
      raw: {
        'canvas': {'width': 1200, 'height': 800},
        'layers': [
          {'name': 'WALLS', 'color': '#2563EB', 'is_visible': true},
          {'name': 'HIDDEN', 'color': '#DC2626', 'is_visible': false},
        ],
        'geometry': [
          {
            'id': 1,
            'entity_type': 'line',
            'layer': 'WALLS',
            'geometry': {
              'kind': 'line',
              'x1': 10,
              'y1': 20,
              'x2': 110,
              'y2': 20,
              'render_path': [10, 20, 110, 20],
            },
            'style': {'color': '#FFFFFF', 'stroke_width': 2},
            'is_visible': true,
          },
          {
            'id': 2,
            'entity_type': 'circle',
            'layer': 'WALLS',
            'geometry': {'kind': 'circle', 'cx': 80, 'cy': 90, 'r': 15},
            'is_visible': true,
          },
          {
            'id': 3,
            'entity_type': 'point',
            'layer': 'WALLS',
            'geometry': {'kind': 'point', 'x': 40, 'y': 50},
            'is_visible': true,
          },
          {
            'id': 4,
            'entity_type': 'text',
            'layer': 'WALLS',
            'geometry': {
              'kind': 'text',
              'x': 25,
              'y': 35,
              'text': 'Room A',
              'height': 14,
            },
            'is_visible': true,
          },
          {
            'id': 5,
            'entity_type': 'arc',
            'layer': 'WALLS',
            'geometry': {
              'kind': 'arc',
              'cx': 200,
              'cy': 200,
              'r': 25,
              'start_angle': 0,
              'end_angle': 1.57,
            },
            'is_visible': true,
          },
          {
            'id': 6,
            'entity_type': 'line',
            'layer': 'HIDDEN',
            'geometry': {
              'kind': 'line',
              'render_path': [0, 0, 10, 10],
            },
            'is_visible': true,
          },
          {
            'id': 7,
            'entity_type': 'line',
            'layer': 'WALLS',
            'geometry': {
              'kind': 'line',
              'render_path': [0, 0, 10, 10],
            },
            'is_visible': false,
          },
        ],
        'rooms': [
          {
            'x': 20,
            'y': 30,
            'w': 220,
            'h': 180,
            'walls': [
              {'wall_id': 91, 'x1': 20, 'y1': 30, 'x2': 240, 'y2': 30},
            ],
          },
        ],
      },
    );

    final geometry = MapGeometryMapper(
      DirectoryManager(),
    ).roomsGeometryFor(record)!;

    expect(geometry.canvas.width, 1200);
    expect(geometry.canvas.height, 800);
    expect(geometry.cadShapes, hasLength(5));
    expect(geometry.cadShapes.whereType<CadPathShape>(), hasLength(2));
    expect(geometry.cadShapes.whereType<CadCircleShape>(), hasLength(1));
    expect(geometry.cadShapes.whereType<CadPointShape>(), hasLength(1));
    expect(geometry.cadShapes.whereType<CadTextShape>(), hasLength(1));

    final line = geometry.cadShapes.first as CadPathShape;
    expect(line.points, const [Offset(10, 20), Offset(110, 20)]);
    expect(line.strokeWidth, 2);
    expect(line.colorValue, 0xFF1F2937);
    expect(
      geometry.cadShapes.whereType<CadCircleShape>().single.colorValue,
      0xFF2563EB,
    );
    expect(geometry.roomRects, hasLength(1));
    expect(geometry.wallLines['91'], isNotNull);
  });
}
