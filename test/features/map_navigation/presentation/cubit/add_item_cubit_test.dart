import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/core/domain/entities/floor.dart';
import 'package:digitization_platform/core/domain/entities/hall.dart';
import 'package:digitization_platform/core/domain/entities/object_metadata.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/features/map_navigation/presentation/cubit/add_item_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeSiteRepository repository;
  late AddItemCubit cubit;

  // The fake's first site, a building of it, and a floor of that building.
  const siteId = 's1';
  const buildingId = 'b2';
  const floorId = 'f2';

  setUp(() {
    repository = FakeSiteRepository();
    cubit = AddItemCubit(
      repository,
      siteId: siteId,
      buildingId: buildingId,
      floorId: floorId,
    );
  });

  tearDown(() => cubit.close());

  WallEntity saved() => repository.findWall(floorId, cubit.state.savedItemId!)!;

  test('opens on a wall for an archaeological site, with its place named', () {
    expect(cubit.state.siteKind, SiteKind.site);
    expect(cubit.state.objectType, ObjectType.wall);
    expect(cubit.state.buildingName, 'Mastaba B');
    expect(cubit.state.floorName, 'Ground Floor');
    expect(cubit.state.savedItemId, isNull);
  });

  test(
    'a name is required, and the complaint clears once one is typed',
    () async {
      await cubit.submit(
        name: '   ',
        notes: '',
        metadata: ObjectMetadata.empty,
      );

      expect(cubit.state.nameError, isNotNull);
      expect(cubit.state.savedItemId, isNull);

      cubit.nameEdited();

      expect(cubit.state.nameError, isNull);
    },
  );

  test('a statue is stored with its hall and what its label says', () async {
    cubit
      ..selectType(ObjectType.statue)
      ..selectHall(const HallEntity(name: 'Garden'));

    await cubit.submit(
      name: '  Seated scribe ',
      notes: ' Left of the doorway ',
      metadata: const ObjectMetadata(inventoryNumber: 'JE 30272', heightCm: 51),
    );
    final item = saved();

    expect(cubit.state.isSaving, isFalse);
    expect(item.name, 'Seated scribe');
    expect(item.notes, 'Left of the doorway');
    expect(item.objectType, ObjectType.statue);
    expect(item.captureMode, CaptureMode.loose);
    expect(item.roomLabel, 'Garden');
    expect(item.metadata.inventoryNumber, 'JE 30272');
    expect(item.metadata.heightCm, 51);
  });

  test(
    'a wall is stored without an object\'s fields, whatever was typed',
    () async {
      cubit.selectType(ObjectType.statue);
      cubit.selectType(ObjectType.wall);

      await cubit.submit(
        name: 'North face',
        notes: '',
        metadata: const ObjectMetadata(material: 'Granite'),
      );

      expect(saved().objectType, ObjectType.wall);
      expect(saved().captureMode, CaptureMode.grid);
      expect(saved().metadata.isEmpty, isTrue);
    },
  );

  test('choosing "none" after a hall files the item under no hall', () async {
    cubit
      ..selectHall(const HallEntity(name: 'Garden'))
      ..selectHall(null);

    await cubit.submit(
      name: 'North face',
      notes: '',
      metadata: ObjectMetadata.empty,
    );

    expect(cubit.state.hall, isNull);
    expect(saved().roomLabel, isNull);
  });

  group('the hall the form opens on', () {
    const hall3 = HallEntity(id: '3', name: 'Hall 3');

    AddItemCubit openedOn(String? hallName) {
      final opened = AddItemCubit(
        _RepositoryWithHalls(const [hall3]),
        siteId: siteId,
        buildingId: buildingId,
        floorId: floorId,
        initialHallName: hallName,
      );
      addTearDown(opened.close);
      return opened;
    }

    test('is the one the operator was looking at', () {
      expect(openedOn('Hall 3').state.hall, hall3);
    });

    test('is none when the floor was not narrowed to a hall', () {
      expect(openedOn(null).state.hall, isNull);
    });

    test('is none when that hall is not on this floor', () {
      expect(openedOn('Somewhere else').state.hall, isNull);
    });
  });
}

/// The fake's floors have no halls of their own; this gives them some.
class _RepositoryWithHalls extends FakeSiteRepository {
  _RepositoryWithHalls(this._halls);

  final List<HallEntity> _halls;

  @override
  FloorEntity? findFloor(String floorId) =>
      super.findFloor(floorId)?.copyWith(halls: _halls);
}
