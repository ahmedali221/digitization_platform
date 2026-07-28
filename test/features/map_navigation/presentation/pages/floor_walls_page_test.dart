import 'package:digitization_platform/core/domain/entities/building.dart';
import 'package:digitization_platform/core/domain/entities/canvas_shape.dart';
import 'package:digitization_platform/core/domain/entities/floor.dart';
import 'package:digitization_platform/core/domain/entities/site.dart';
import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/core/domain/repositories/site_repository.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:digitization_platform/features/map_navigation/domain/entities/map_geometry.dart';
import 'package:digitization_platform/features/map_navigation/domain/repositories/map_geometry_repository.dart';
import 'package:digitization_platform/features/map_navigation/presentation/pages/floor_walls_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  const northWall = WallEntity(
    id: 'wall-north',
    floorId: 'floor-1',
    name: 'North Wall',
    status: WallStatus.done,
    lastCapture: 'Today',
  );
  const southWall = WallEntity(
    id: 'wall-south',
    floorId: 'floor-1',
    name: 'South Wall',
    status: WallStatus.notStarted,
    lastCapture: 'Never',
  );
  const looseWall = WallEntity(
    id: 'wall-loose',
    floorId: 'floor-1',
    name: 'Loose Wall',
    status: WallStatus.inProgress,
    lastCapture: 'Yesterday',
  );
  const floor = FloorEntity(
    id: 'floor-1',
    buildingId: 'building-1',
    name: 'Ground Floor',
    walls: [northWall, southWall, looseWall],
  );
  const building = BuildingEntity(
    id: 'building-1',
    siteId: 'site-1',
    name: 'Main Building',
    floors: [floor],
  );
  const site = SiteEntity(
    id: 'site-1',
    name: 'Test Site',
    location: 'Luxor',
    availability: SiteAvailability.ready,
    buildings: [building],
  );
  const geometry = FloorRoomsGeometry(
    canvas: CanvasSize(width: 400, height: 200),
    cadShapes: [],
    rooms: [
      FloorRoomGeometry(
        id: 'room-a',
        label: 'Room A',
        rect: RectShape(x: 0, y: 0, w: 180, h: 180),
        wallIds: {'wall-north'},
      ),
      FloorRoomGeometry(
        id: 'room-b',
        label: 'Room B',
        rect: RectShape(x: 220, y: 0, w: 180, h: 180),
        wallIds: {'wall-south'},
      ),
    ],
    wallLines: {
      'wall-north': WallLineShape(x1: 0, y1: 0, x2: 180, y2: 0),
      'wall-south': WallLineShape(x1: 220, y1: 0, x2: 400, y2: 0),
    },
  );

  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<SiteRepository>(_TestSiteRepository(site));
    GetIt.instance.registerSingleton<MapGeometryRepository>(
      _TestGeometryRepository(geometry),
    );
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('shows only walls from the selected room', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FloorWallsPage(
          siteId: 'site-1',
          buildingId: 'building-1',
          floorId: 'floor-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('North Wall'), findsOneWidget);
    expect(find.text('South Wall'), findsNothing);
    expect(find.text('Loose Wall'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('room-filter-room-b')));
    await tester.pump();

    expect(find.text('North Wall'), findsNothing);
    expect(find.text('South Wall'), findsOneWidget);
    expect(find.text('Loose Wall'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('room-filter-_unassigned_walls')),
    );
    await tester.pump();

    expect(find.text('North Wall'), findsNothing);
    expect(find.text('South Wall'), findsNothing);
    expect(find.text('Loose Wall'), findsOneWidget);
  });
}

class _TestSiteRepository extends Fake implements SiteRepository {
  _TestSiteRepository(this.site);

  final SiteEntity site;

  @override
  Stream<List<SiteEntity>> watchSites() => Stream.value([site]);
}

class _TestGeometryRepository extends Fake implements MapGeometryRepository {
  _TestGeometryRepository(this.geometry);

  final FloorRoomsGeometry geometry;

  @override
  FloorRoomsGeometry? roomsGeometryFor(String siteId, String floorId) =>
      geometry;
}
