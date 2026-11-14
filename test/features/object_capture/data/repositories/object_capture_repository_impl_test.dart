import 'dart:io';

import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/core/domain/entities/new_item_draft.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:digitization_platform/features/object_capture/data/datasources/object_capture_local_data_source.dart';
import 'package:digitization_platform/features/object_capture/data/repositories/object_capture_repository_impl.dart';
import 'package:digitization_platform/features/sync_queue/domain/entities/sync_item_kind.dart';
import 'package:digitization_platform/features/sync_queue/domain/repositories/sync_enqueuer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../support/hive_harness.dart';
import '../../../../support/temp_directory_manager.dart';

typedef _Enqueued = ({
  String wallId,
  String siteId,
  String name,
  SyncItemKind kind,
});

class _RecordingEnqueuer implements SyncEnqueuer {
  final List<_Enqueued> enqueued = [];

  @override
  Future<void> enqueueCapture({
    required String wallId,
    required String siteId,
    required String displayName,
    required SyncItemKind kind,
  }) async {
    enqueued.add((
      wallId: wallId,
      siteId: siteId,
      name: displayName,
      kind: kind,
    ));
  }
}

void main() {
  final hive = HiveHarness();
  late TempDirectoryManager directories;
  late FakeSiteRepository sites;
  late _RecordingEnqueuer enqueuer;
  late ObjectCaptureRepositoryImpl repository;
  late String statueId;
  var shotCounter = 0;

  // A floor of the fake's first site, s1.
  const floorId = 'f2';

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    directories = await TempDirectoryManager.create();
    sites = FakeSiteRepository();
    enqueuer = _RecordingEnqueuer();
    repository = ObjectCaptureRepositoryImpl(
      siteRepository: sites,
      local: ObjectCaptureLocalDataSource(directoryManager: directories),
      syncEnqueuer: enqueuer,
    );
    statueId = await sites.addItem(
      floorId,
      const NewItemDraft(name: 'Seated scribe', objectType: ObjectType.statue),
    );
  });

  tearDown(() => directories.dispose());

  /// A shot as the camera leaves it: a file in the incoming folder.
  Future<String> shoot() async {
    final folder = await repository.incomingFolder(statueId);
    final file = File(p.join(folder, 'shot_${shotCounter++}.jpg'));
    await file.writeAsString('photograph $shotCounter');
    return file.path;
  }

  Future<void> shootSide(ObjectSide side) async {
    await repository.setSidePhoto(
      floorId: floorId,
      wallId: statueId,
      side: side,
      shotPath: await shoot(),
    );
  }

  String backupOf(String keptPath) =>
      p.join(directories.root.path, 'backup', statueId, p.basename(keptPath));

  test(
    'a side photograph is kept, backed up, and taken out of the camera\'s folder',
    () async {
      final shotPath = await shoot();

      await repository.setSidePhoto(
        floorId: floorId,
        wallId: statueId,
        side: ObjectSide.front,
        shotPath: shotPath,
      );

      final photo = repository
          .getCapture(statueId)
          .sidePhotos[ObjectSide.front]!;
      expect(File(photo.path).existsSync(), isTrue);
      expect(File(backupOf(photo.path)).existsSync(), isTrue);
      expect(File(shotPath).existsSync(), isFalse);
      expect(photo.isUploaded, isFalse);
    },
  );

  test(
    'a retake replaces the side\'s photograph and removes the old files',
    () async {
      await shootSide(ObjectSide.front);
      final first = repository
          .getCapture(statueId)
          .sidePhotos[ObjectSide.front]!;

      await shootSide(ObjectSide.front);
      final capture = repository.getCapture(statueId);

      expect(capture.photos, hasLength(1));
      expect(capture.sidePhotos[ObjectSide.front]!.path, isNot(first.path));
      expect(File(first.path).existsSync(), isFalse);
      expect(File(backupOf(first.path)).existsSync(), isFalse);
    },
  );

  test('free photographs are added in the order they were taken', () async {
    final shots = [await shoot(), await shoot(), await shoot()];

    await repository.addFreePhotos(
      floorId: floorId,
      wallId: statueId,
      shotPaths: shots,
    );
    final photos = repository.getCapture(statueId).freePhotos;

    expect(photos, hasLength(3));
    expect(photos.map((photo) => photo.path).toSet(), hasLength(3));
    expect(photos.every((photo) => File(photo.path).existsSync()), isTrue);
  });

  test(
    'a shot left in the camera\'s folder is picked up as a free photograph',
    () async {
      await shoot();
      await shoot();
      expect(repository.getCapture(statueId).isEmpty, isTrue);

      await repository.adoptStrayShots(floorId: floorId, wallId: statueId);

      expect(repository.getCapture(statueId).freePhotos, hasLength(2));
    },
  );

  test('a description is stored, and a changed one is sent again', () async {
    await repository.addFreePhotos(
      floorId: floorId,
      wallId: statueId,
      shotPaths: [await shoot()],
    );
    final path = repository.getCapture(statueId).freePhotos.single.path;

    await repository.setComment(
      wallId: statueId,
      photoPath: path,
      comment: 'Inscription on the back pillar',
    );
    final photo = repository.getCapture(statueId).freePhotos.single;

    expect(photo.comment, 'Inscription on the back pillar');
    expect(photo.isUploaded, isFalse);
  });

  test('a deleted photograph is gone from the capture and from disk', () async {
    await shootSide(ObjectSide.top);
    final photo = repository.getCapture(statueId).photos.single;

    await repository.deletePhoto(wallId: statueId, photoPath: photo.path);

    expect(repository.getCapture(statueId).isEmpty, isTrue);
    expect(File(photo.path).existsSync(), isFalse);
    expect(File(backupOf(photo.path)).existsSync(), isFalse);
  });

  test(
    'saving a part-shot object marks it in progress and queues it',
    () async {
      await shootSide(ObjectSide.front);

      await repository.save(floorId: floorId, wallId: statueId);

      expect(sites.findWall(floorId, statueId)!.status, WallStatus.inProgress);
      expect(enqueuer.enqueued.single, (
        wallId: statueId,
        siteId: 's1',
        name: 'Seated scribe',
        kind: SyncItemKind.objectPhotos,
      ));
    },
  );

  test('saving all six sides marks the object captured', () async {
    for (final side in ObjectSide.values) {
      await shootSide(side);
    }

    await repository.save(floorId: floorId, wallId: statueId);

    expect(sites.findWall(floorId, statueId)!.status, WallStatus.captured);
  });

  test('saving after every photograph was deleted queues nothing', () async {
    await shootSide(ObjectSide.front);
    final path = repository.getCapture(statueId).photos.single.path;
    await repository.deletePhoto(wallId: statueId, photoPath: path);

    await repository.save(floorId: floorId, wallId: statueId);

    expect(sites.findWall(floorId, statueId)!.status, WallStatus.notStarted);
    expect(enqueuer.enqueued, isEmpty);
  });

  test('the capture stream reports each change', () async {
    final counts = <int>[];
    final subscription = repository
        .watchCapture(statueId)
        .listen((capture) => counts.add(capture.photos.length));

    await shootSide(ObjectSide.front);
    await shootSide(ObjectSide.back);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(counts.first, 0);
    expect(counts.last, 2);
  });
}
