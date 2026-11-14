import 'package:digitization_platform/core/data/mappers/site_mapper.dart';
import 'package:digitization_platform/core/data/models/floor_package_record.dart';
import 'package:digitization_platform/core/data/models/site_package_record.dart';
import 'package:digitization_platform/core/domain/entities/floor.dart';
import 'package:digitization_platform/core/domain/entities/hall.dart';
import 'package:digitization_platform/core/domain/entities/object_metadata.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/domain/entities/site.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SiteMapper();

  SiteEntity mapSite({
    required Map<String, dynamic> floor,
    String? kind,
  }) {
    return mapper.mapSite(
      SitePackageRecord(
        siteId: '1',
        name: 'Egyptian Museum',
        kind: kind,
        raw: {
          'site': {'id': 1, 'name': 'Egyptian Museum'},
          'buildings': [
            {
              'id': 10,
              'name': 'Main building',
              'floors': [
                {'id': 100, 'name': 'Ground floor'},
              ],
            },
          ],
        },
      ),
      [
        FloorPackageRecord(
          floorId: '100',
          siteId: '1',
          raw: {
            'floor': {'id': 100, 'name': 'Ground floor'},
            ...floor,
          },
          downloadedAt: DateTime(2026, 11, 13),
        ),
      ],
      const {},
      availability: SiteAvailability.ready,
    );
  }

  FloorEntity floorOf(SiteEntity site) => site.buildings.single.floors.single;

  group('a bundle that lists items', () {
    final site = mapSite(
      kind: 'museum',
      floor: {
        // The canvas draws one wall of the hall; the statue is nowhere on it.
        'rooms': [
          {
            'id': 5,
            'chamber_id': 7,
            'label': 'Hall 3',
            'walls': [
              {'wall_id': 41, 'name': 'North wall', 'edge': 'north'},
            ],
          },
        ],
        'chambers': [
          {'id': 7, 'name': 'Hall 3'},
          {'id': 8, 'name': 'Garden'},
        ],
        'items': [
          {
            'wall_id': 41,
            'chamber_id': 7,
            'chamber_name': 'Hall 3',
            'name': 'North wall',
            'notes': null,
            'object_type': 'wall',
            'capture_mode': 'grid',
            'intake_status': 'accepted',
            'metadata': <String, dynamic>{},
          },
          {
            'wall_id': 42,
            'chamber_id': 7,
            'chamber_name': 'Hall 3',
            'name': 'Seated scribe',
            'notes': 'Left of the doorway',
            'object_type': 'statue',
            'capture_mode': 'loose',
            'intake_status': 'pending',
            'metadata': {
              'inventory_number': 'JE 30272',
              'material': 'Painted limestone',
              'period': null,
              'height_cm': 51,
              'width_cm': 41.5,
              'depth_cm': null,
            },
          },
        ],
        'wall_status_index': {
          '41': {'status': 'done', 'grid_rows': 2, 'grid_cols': 3},
          '42': {
            'status': 'in_progress',
            'sides_captured': ['front', 'left'],
          },
        },
      },
    );

    test('reads the site as a museum', () {
      expect(site.kind, SiteKind.museum);
      expect(site.isMuseum, isTrue);
    });

    test('includes a record the canvas does not draw', () {
      expect(floorOf(site).walls.map((wall) => wall.id), ['41', '42']);
    });

    test('maps an object with its type, hall, metadata and sides', () {
      final statue = floorOf(site).walls.last;

      expect(statue.name, 'Seated scribe');
      expect(statue.notes, 'Left of the doorway');
      expect(statue.objectType, ObjectType.statue);
      expect(statue.captureMode, CaptureMode.loose);
      expect(statue.intakeStatus, IntakeStatus.pending);
      expect(statue.isAwaitingReview, isTrue);
      expect(statue.roomLabel, 'Hall 3');
      expect(statue.hallId, '7');
      expect(statue.status, WallStatus.inProgress);
      expect(statue.capturedSides, {ObjectSide.front, ObjectSide.left});
      expect(statue.grid, isNull);
      expect(
        statue.metadata,
        const ObjectMetadata(
          inventoryNumber: 'JE 30272',
          material: 'Painted limestone',
          heightCm: 51,
          widthCm: 41.5,
        ),
      );
    });

    test('keeps a wall a wall, with its grid', () {
      final wall = floorOf(site).walls.first;

      expect(wall.objectType, ObjectType.wall);
      expect(wall.captureMode, CaptureMode.grid);
      expect(wall.metadata.isEmpty, isTrue);
      expect(wall.grid?.rows, 2);
      expect(wall.grid?.cols, 3);
      expect(wall.isLocal, isFalse);
    });

    test('offers every hall of the floor, drawn or not', () {
      expect(floorOf(site).halls, const [
        HallEntity(id: '7', name: 'Hall 3'),
        HallEntity(id: '8', name: 'Garden'),
      ]);
    });
  });

  group('a bundle published before items existed', () {
    final site = mapSite(
      floor: {
        'rooms': [
          {
            'id': 5,
            'chamber_id': 7,
            'label': 'Chamber J',
            'walls': [
              {'wall_id': 41, 'name': 'North wall', 'edge': 'north'},
              {'wall_id': 43, 'edge': 'east'},
            ],
          },
        ],
        'wall_status_index': {
          '41': {'status': 'captured', 'capture_mode': 'loose'},
        },
      },
    );

    test('reads as a site of walls from the drawn rooms', () {
      final walls = floorOf(site).walls;

      expect(site.kind, SiteKind.site);
      expect(walls.map((wall) => wall.id), ['41', '43']);
      expect(walls.every((wall) => wall.objectType == ObjectType.wall), isTrue);
      expect(walls.last.name, 'East wall');
    });

    test('takes the capture mode from the status index', () {
      final walls = floorOf(site).walls;

      expect(walls.first.captureMode, CaptureMode.loose);
      expect(walls.last.captureMode, CaptureMode.grid);
    });

    test('offers the halls its rooms name', () {
      expect(floorOf(site).halls, const [
        HallEntity(id: '7', name: 'Chamber J'),
      ]);
    });
  });
}
