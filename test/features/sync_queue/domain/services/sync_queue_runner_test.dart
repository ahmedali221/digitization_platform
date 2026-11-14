import 'package:digitization_platform/core/data/datasources/site_local_data_source.dart';
import 'package:digitization_platform/core/domain/entities/new_item_draft.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/core/storage/device_id_provider.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_queue_local_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_remote_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/models/sync_queue_item_record.dart';
import 'package:digitization_platform/features/sync_queue/domain/entities/sync_item_kind.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/capture_uploader.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/field_item_registrar.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/sync_queue_runner.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/hive_harness.dart';

/// Records what the runner asks of it, in order, and fails on request.
class _RecordingUploader implements CaptureUploader {
  final List<String> calls = [];
  bool holdsCapture = true;
  Object? failure;

  @override
  bool hasCapture(String localWallId) => holdsCapture;

  @override
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  }) async {
    calls.add('upload $localWallId -> $serverWallId');
    final failure = this.failure;
    if (failure != null) throw failure;
    onProgress(1);
  }

  @override
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  }) async {
    calls.add('deleteBackups $localWallId');
  }
}

void main() {
  final hive = HiveHarness();
  late SiteLocalDataSource siteLocal;
  late SyncQueueLocalDataSource queueLocal;
  late _RecordingUploader gridUploader;
  late _RecordingUploader objectUploader;
  late SyncQueueRunner runner;
  late int createRequests;
  late bool serverSaysArchived;

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    siteLocal = SiteLocalDataSource();
    queueLocal = SyncQueueLocalDataSource();
    gridUploader = _RecordingUploader();
    objectUploader = _RecordingUploader();
    createRequests = 0;
    serverSaysArchived = false;

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            createRequests++;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'wall_id': 42,
                  'intake_status': 'accepted',
                  'is_archived': serverSaysArchived,
                  'created_at': '2026-11-13T10:00:00+00:00',
                },
              ),
            );
          },
        ),
      );

    runner = SyncQueueRunner(
      queueLocal: queueLocal,
      registrar: FieldItemRegistrar(
        siteLocal: siteLocal,
        remote: SyncRemoteDataSource(dio),
        deviceIdProvider: DeviceIdProvider(),
      ),
      uploaders: {
        SyncItemKind.gridSession: gridUploader,
        SyncItemKind.objectPhotos: objectUploader,
      },
    );
  });

  Future<SyncQueueItemRecord> queue(
    String wallId, {
    SyncItemKind kind = SyncItemKind.gridSession,
  }) async {
    final record = SyncQueueItemRecord(
      id: wallId,
      sessionId: wallId,
      wallId: wallId,
      siteId: '1',
      displayName: 'Item $wallId',
      status: 'queued',
      createdAt: DateTime(2026, 11, 13),
      kindName: kind.name,
    );
    await queueLocal.put(record);
    return record;
  }

  Future<String> addLocalItem(ObjectType type) {
    return siteLocal.addLocalItem(
      floorId: '100',
      draft: NewItemDraft(name: 'Field item', objectType: type),
    );
  }

  test('a wall from a package is uploaded and then loses its backups', () async {
    final item = await queue('41');

    await runner.drainAll();

    expect(gridUploader.calls, ['upload 41 -> 41', 'deleteBackups 41']);
    expect(objectUploader.calls, isEmpty);
    expect(createRequests, 0);
    expect(item.status, 'confirmed');
    expect(item.progress, 100);
  });

  test('an item goes to the uploader for its kind', () async {
    await queue('41', kind: SyncItemKind.objectPhotos);

    await runner.drainAll();

    expect(objectUploader.calls, ['upload 41 -> 41', 'deleteBackups 41']);
    expect(gridUploader.calls, isEmpty);
  });

  test(
    'an item added on this phone is created on the server, then uploaded '
    'under the id the server gave it',
    () async {
      final localId = await addLocalItem(ObjectType.statue);
      final item = await queue(localId, kind: SyncItemKind.objectPhotos);

      await runner.drainAll();

      expect(createRequests, 1);
      expect(objectUploader.calls, [
        'upload $localId -> 42',
        'deleteBackups $localId',
      ]);
      expect(item.status, 'confirmed');
      expect(item.wallId, localId, reason: 'the phone keeps its own id');
    },
  );

  test('a second upload of the same item does not create it twice', () async {
    final localId = await addLocalItem(ObjectType.wall);
    await queue(localId);
    await runner.drainAll();

    await queue(localId);
    await runner.drainAll();

    expect(createRequests, 1);
    expect(gridUploader.calls.where((call) => call.startsWith('upload')), [
      'upload $localId -> 42',
      'upload $localId -> 42',
    ]);
  });

  test('a rejected item is not uploaded, and says why', () async {
    serverSaysArchived = true;
    final localId = await addLocalItem(ObjectType.statue);
    final item = await queue(localId, kind: SyncItemKind.objectPhotos);

    await runner.drainAll();

    expect(objectUploader.calls, isEmpty);
    expect(item.status, 'failed');
    expect(item.lastError, contains('rejected'));
  });

  test('an item with nothing on this phone fails without touching the network', () async {
    gridUploader.holdsCapture = false;
    final localId = await addLocalItem(ObjectType.wall);
    final item = await queue(localId);

    await runner.drainAll();

    expect(createRequests, 0);
    expect(item.status, 'failed');
    expect(item.lastError, isNotEmpty);
  });

  test('a network failure leaves the item queued and its backups in place', () async {
    gridUploader.failure = const AppException(NetworkFailure());
    final item = await queue('41');

    await runner.drainAll();

    expect(item.status, 'queued');
    expect(item.attempts, 1);
    expect(gridUploader.calls, ['upload 41 -> 41']);
  });

  test('a refusal by the server is final until the operator retries', () async {
    gridUploader.failure = const AppException(
      ValidationFailure('The wall is finished.', {}),
    );
    final item = await queue('41');

    await runner.drainAll();

    expect(item.status, 'failed');
    expect(item.lastError, 'The wall is finished.');
    expect(gridUploader.calls, ['upload 41 -> 41']);
  });

  test('confirmed and failed items are left alone by a drain', () async {
    final confirmed = await queue('41');
    confirmed.status = 'confirmed';
    await queueLocal.put(confirmed);
    final failed = await queue('43');
    failed.status = 'failed';
    await queueLocal.put(failed);

    await runner.drainAll();

    expect(gridUploader.calls, isEmpty);
  });
}
