import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeSiteRepository hierarchy', () {
    late FakeSiteRepository repository;

    setUp(() {
      repository = FakeSiteRepository();
    });

    test(
      'every site contains buildings, floors, and floor-owned walls',
      () async {
        final sites = await repository.watchSites().first;

        expect(sites, isNotEmpty);
        for (final site in sites) {
          expect(
            site.buildings,
            isNotEmpty,
            reason: '${site.name} should contain at least one building',
          );

          for (final building in site.buildings) {
            expect(
              building.floors,
              isNotEmpty,
              reason: '${site.name} / ${building.name} should contain floors',
            );

            for (final floor in building.floors) {
              expect(floor.buildingId, building.id);
              expect(
                floor.walls,
                isNotEmpty,
                reason:
                    '${site.name} / ${building.name} / ${floor.name} should contain walls',
              );
              expect(
                floor.walls.every((wall) => wall.floorId == floor.id),
                isTrue,
              );
            }
          }
        }
      },
    );

    test('Mastaba A has a Ground Floor that owns North face', () {
      final building = repository.findBuilding('b1');

      expect(building, isNotNull);
      expect(building!.name, 'Mastaba A');
      expect(building.floors, hasLength(2));
      final groundFloor = building.floors.firstWhere(
        (floor) => floor.name == 'Ground Floor',
      );
      expect(
        groundFloor.walls.map((wall) => wall.name),
        contains('North face'),
      );
    });

    test('walls can contain multiple captures in a grid cell', () {
      final wall = repository.findWall('f1', 'f1-w3');

      expect(wall, isNotNull);
      expect(wall!.grid, isNotNull);
      expect(wall.grid!.cells.first.shotPaths, hasLength(2));
    });

    test('unavailable sites retain their published wall totals', () {
      expect(repository.findSite('s3')!.wallsTotal, 40);
      expect(repository.findSite('s4')!.wallsTotal, 80);
      expect(repository.findSite('s6')!.wallsTotal, 55);
      expect(repository.findSite('s7')!.wallsTotal, 45);
    });
  });
}
