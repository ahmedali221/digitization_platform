import 'dart:io';

import 'package:digitization_platform/core/storage/device_id_provider.dart';
import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/core/storage/hive_boxes.dart';
import 'package:digitization_platform/features/grid_capture/data/datasources/capture_session_local_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_queue_local_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_remote_data_source.dart';
import 'package:digitization_platform/features/sync_queue/data/models/sync_queue_item_record.dart';
import 'package:digitization_platform/features/sync_queue/data/repositories/sync_queue_repository_impl.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/sync_queue_runner.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory hiveDir;
  late SyncQueueRepositoryImpl repository;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('wallbase-sync-queue-');
    Hive.init(hiveDir.path);
    await registerAdaptersAndOpenBoxes();

    // Never actually reached by the case under test — enqueueSession must
    // return before calling into the runner at all — so real (unused)
    // dependencies are enough.
    final runner = SyncQueueRunner(
      queueLocal: SyncQueueLocalDataSource(),
      sessionLocal: CaptureSessionLocalDataSource(),
      remote: SyncRemoteDataSource(Dio()),
      deviceIdProvider: DeviceIdProvider(),
      directoryManager: DirectoryManager(),
    );
    repository = SyncQueueRepositoryImpl(SyncQueueLocalDataSource(), runner);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
  });

  test(
    'enqueueSession refuses to queue an unresolved local wall id',
    () async {
      await repository.enqueueSession(
        wallId: 'local_1c139026',
        siteId: '1',
        displayName: 'Wall A',
      );

      expect(Hive.box<SyncQueueItemRecord>(HiveBoxes.syncQueue).values, isEmpty);
    },
  );
}
