import 'package:digitization_platform/core/data/datasources/site_local_data_source.dart';
import 'package:digitization_platform/core/data/datasources/site_remote_data_source.dart';
import 'package:digitization_platform/core/data/models/floor_package_record.dart';
import 'package:digitization_platform/core/data/models/id_mapping_record.dart';
import 'package:digitization_platform/core/data/models/site_package_record.dart';
import 'package:digitization_platform/core/data/models/wall_status_record.dart';
import 'package:digitization_platform/core/data/repositories/site_repository_impl.dart';
import 'package:digitization_platform/core/domain/entities/hall.dart';
import 'package:digitization_platform/core/domain/entities/new_item_draft.dart';
import 'package:digitization_platform/core/domain/entities/object_metadata.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/core/network/file_downloader.dart';
import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:digitization_platform/features/site_sync/domain/services/site_download_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/hive_harness.dart';

void main() {
  final hive = HiveHarness();
  late SiteLocalDataSource local;
  late SiteRepositoryImpl repository;

  const siteId = '1';
  const floorId = '100';
  final registeredAt = DateTime.utc(2026, 11, 13, 10);

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    local = SiteLocalDataSource();
    final remote = SiteRemoteDataSource(Dio());
    final directoryManager = DirectoryManager();
    repository = SiteRepositoryImpl(
      local: local,
      remote: remote,
      downloadService: SiteDownloadService(
        remote: remote,
        local: local,
        downloader: FileDownloader(Dio()),
        directoryManager: directoryManager,
        dio: Dio(),
      ),
      directoryManager: directoryManager,
    );
  });

  tearDown(() => repository.dispose());

  /// Stores a downloaded bundle whose one floor lists [items].
  Future<void> putBundle({
    required DateTime publishedAt,
    List<Map<String, dynamic>> items = const [],
    Map<String, dynamic> wallStatusIndex = const {},
  }) async {
    await local.putSite(
      SitePackageRecord(
        siteId: siteId,
        name: 'Egyptian Museum',
        kind: 'museum',
        raw: {
          'site': {
            'id': 1,
            'name': 'Egyptian Museum',
            'published_at': publishedAt.toIso8601String(),
          },
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
    );
    await local.putFloor(
      FloorPackageRecord(
        floorId: floorId,
        siteId: siteId,
        raw: {
          'floor': {'id': 100, 'name': 'Ground floor'},
          'rooms': const <dynamic>[],
          'chambers': [
            {'id': 7, 'name': 'Hall 3'},
          ],
          'items': items,
          'wall_status_index': wallStatusIndex,
        },
        downloadedAt: publishedAt,
      ),
    );
  }

  Future<String> addStatue() {
    return repository.addItem(
      floorId,
      const NewItemDraft(
        name: 'Seated scribe',
        objectType: ObjectType.statue,
        notes: 'Left of the doorway',
        hall: HallEntity(name: 'Garden'),
        metadata: ObjectMetadata(inventoryNumber: 'JE 30272'),
      ),
    );
  }

  Future<void> markRegistered(String localId, String serverWallId) {
    return local.putIdMapping(
      IdMappingRecord(
        localId: localId,
        wallId: serverWallId,
        resolvedAt: registeredAt,
      ),
    );
  }

  List<WallEntity> walls() => repository.findFloor(floorId)!.walls;

  test('an added item is on its floor at once, as it was entered', () async {
    await putBundle(publishedAt: registeredAt);

    final localId = await addStatue();
    final item = walls().single;

    expect(localId, startsWith(WallEntity.localIdPrefix));
    expect(item.id, localId);
    expect(item.name, 'Seated scribe');
    expect(item.notes, 'Left of the doorway');
    expect(item.objectType, ObjectType.statue);
    expect(item.captureMode, CaptureMode.loose);
    expect(item.roomLabel, 'Garden');
    expect(item.metadata.inventoryNumber, 'JE 30272');
    expect(item.status, WallStatus.notStarted);
    expect(item.isOnlyOnThisPhone, isTrue);
  });

  test('a hall named on this phone is offered for the next item', () async {
    await putBundle(publishedAt: registeredAt);

    await addStatue();

    expect(repository.findFloor(floorId)!.halls, const [
      HallEntity(id: '7', name: 'Hall 3'),
      HallEntity(name: 'Garden'),
    ]);
  });

  test(
    'once sent, an item keeps its local id and knows its server id',
    () async {
      await putBundle(
        publishedAt: registeredAt.subtract(const Duration(days: 1)),
      );
      final localId = await addStatue();

      await markRegistered(localId, '42');
      final item = walls().single;

      expect(item.id, localId);
      expect(item.serverId, '42');
      expect(item.isOnlyOnThisPhone, isFalse);
    },
  );

  test(
    'a bundle that carries the sent item shows it once, under the local id',
    () async {
      final localId = await addStatue();
      await markRegistered(localId, '42');
      await local.putWallStatus(
        WallStatusRecord(
          wallId: localId,
          status: WallStatus.captured.name,
          dirty: true,
          updatedAt: DateTime.now(),
        ),
      );

      await putBundle(
        publishedAt: registeredAt.add(const Duration(hours: 1)),
        items: [
          {
            'wall_id': 42,
            'chamber_id': 9,
            'chamber_name': 'Garden',
            // Renamed on the dashboard since it was sent.
            'name': 'Seated scribe of Saqqara',
            'object_type': 'statue',
            'capture_mode': 'loose',
            'intake_status': 'pending',
            'metadata': {'inventory_number': 'JE 30272'},
          },
        ],
        wallStatusIndex: {
          '42': {
            'status': 'in_progress',
            'sides_captured': ['front'],
          },
        },
      );
      final item = walls().single;

      expect(item.id, localId, reason: 'its photos are keyed by the local id');
      expect(item.serverId, '42');
      expect(item.name, 'Seated scribe of Saqqara');
      expect(item.hallId, '9');
      expect(item.intakeStatus, IntakeStatus.pending);
      expect(item.capturedSides, {ObjectSide.front});
      expect(
        item.status,
        WallStatus.captured,
        reason: 'this phone has photographed more than the server yet holds',
      );
    },
  );

  test(
    'a bundle built after the item was sent, without it, drops the item',
    () async {
      final localId = await addStatue();
      await markRegistered(localId, '42');

      // Rejected on the dashboard: archived, so no longer published.
      await putBundle(publishedAt: registeredAt.add(const Duration(hours: 1)));

      expect(walls(), isEmpty);
    },
  );

  test(
    'a bundle built before the item was sent does not hide the item',
    () async {
      final localId = await addStatue();
      await markRegistered(localId, '42');

      await putBundle(
        publishedAt: registeredAt.subtract(const Duration(hours: 1)),
      );

      expect(walls().single.id, localId);
    },
  );

  test('an item never sent survives any number of new bundles', () async {
    final localId = await addStatue();

    await putBundle(publishedAt: registeredAt.add(const Duration(days: 30)));

    expect(walls().single.id, localId);
  });
}
