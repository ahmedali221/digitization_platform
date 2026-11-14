import 'package:digitization_platform/core/data/datasources/site_local_data_source.dart';
import 'package:digitization_platform/core/storage/device_id_provider.dart';
import 'package:digitization_platform/core/storage/hive_boxes.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_queue_local_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_remote_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/models/sync_queue_item_record.dart';
import 'package:digitization_platform/features/sync_queue/data/repositories/sync_queue_repository_impl.dart';
import 'package:digitization_platform/features/sync_queue/domain/entities/sync_item_kind.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/capture_uploader.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/field_item_registrar.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/sync_queue_runner.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../support/hive_harness.dart';

/// Has nothing to send, so the runner stops before it reaches the network.
class _NoCaptureUploader implements CaptureUploader {
  @override
  bool hasCapture(String localWallId) => false;

  @override
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  }) async {}

  @override
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  }) async {}
}

void main() {
  final hive = HiveHarness();
  late SyncQueueRepositoryImpl repository;

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();

    final uploader = _NoCaptureUploader();
    final runner = SyncQueueRunner(
      queueLocal: SyncQueueLocalDataSource(),
      registrar: FieldItemRegistrar(
        siteLocal: SiteLocalDataSource(),
        remote: SyncRemoteDataSource(Dio()),
        deviceIdProvider: DeviceIdProvider(),
      ),
      uploaders: {
        SyncItemKind.gridSession: uploader,
        SyncItemKind.objectPhotos: uploader,
      },
    );
    repository = SyncQueueRepositoryImpl(SyncQueueLocalDataSource(), runner);
  });

  SyncQueueItemRecord? queued(String id) =>
      Hive.box<SyncQueueItemRecord>(HiveBoxes.syncQueue).get(id);

  test(
    'a wall created on this phone is queued under its local id, with its kind',
    () async {
      await repository.enqueueCapture(
        wallId: 'local_1c139026',
        siteId: '1',
        displayName: 'Seated scribe',
        kind: SyncItemKind.objectPhotos,
      );

      final item = queued('local_1c139026')!;
      expect(item.wallId, 'local_1c139026');
      expect(item.displayName, 'Seated scribe');
      expect(item.kind, SyncItemKind.objectPhotos);
    },
  );

  test(
    'saving a wall again resets its entry instead of adding a second',
    () async {
      await repository.enqueueCapture(
        wallId: '41',
        siteId: '1',
        displayName: 'North wall',
        kind: SyncItemKind.gridSession,
      );
      final firstQueuedAt = queued('41')!.createdAt;

      await repository.enqueueCapture(
        wallId: '41',
        siteId: '1',
        displayName: 'North wall (renamed)',
        kind: SyncItemKind.gridSession,
      );

      expect(Hive.box<SyncQueueItemRecord>(HiveBoxes.syncQueue).length, 1);
      expect(queued('41')!.displayName, 'North wall (renamed)');
      expect(queued('41')!.createdAt, firstQueuedAt);
    },
  );

  test('an item queued before kinds existed reads as a grid session', () {
    final record = SyncQueueItemRecord(
      id: '42',
      sessionId: '42',
      wallId: '42',
      siteId: '1',
      displayName: 'North wall',
      status: 'queued',
      createdAt: DateTime(2026),
    );

    expect(record.kind, SyncItemKind.gridSession);
  });
}
