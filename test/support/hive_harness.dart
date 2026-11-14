import 'dart:io';

import 'package:digitization_platform/core/data/models/floor_package_record.dart';
import 'package:digitization_platform/core/data/models/id_mapping_record.dart';
import 'package:digitization_platform/core/data/models/site_package_record.dart';
import 'package:digitization_platform/core/data/models/wall_status_record.dart';
import 'package:digitization_platform/core/storage/hive_boxes.dart';
import 'package:digitization_platform/features/grid_capture/data/models/capture_session_record.dart';
import 'package:digitization_platform/features/object_capture/data/models/object_capture_record.dart';
import 'package:digitization_platform/features/object_capture/data/models/object_scan_record.dart';
import 'package:digitization_platform/features/sync_queue/data/models/sync_queue_item_record.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive for one test file: every app box, opened once in a throwaway folder
/// — an adapter can be registered only once per isolate — and emptied by
/// [reset] between tests.
class HiveHarness {
  late final Directory _folder;

  /// Call from `setUpAll`.
  Future<void> open() async {
    _folder = await Directory.systemTemp.createTemp('wallbase-test-hive-');
    Hive.init(_folder.path);
    await registerAdaptersAndOpenBoxes();
  }

  /// Call from `setUp`.
  Future<void> reset() async {
    await Future.wait([
      Hive.box<SitePackageRecord>(HiveBoxes.sites).clear(),
      Hive.box<FloorPackageRecord>(HiveBoxes.floors).clear(),
      Hive.box<WallStatusRecord>(HiveBoxes.wallStatus).clear(),
      Hive.box<CaptureSessionRecord>(HiveBoxes.sessions).clear(),
      Hive.box(HiveBoxes.unassigned).clear(),
      Hive.box<SyncQueueItemRecord>(HiveBoxes.syncQueue).clear(),
      Hive.box<IdMappingRecord>(HiveBoxes.idMappings).clear(),
      Hive.box(HiveBoxes.device).clear(),
      Hive.box<ObjectCaptureRecord>(HiveBoxes.objectCaptures).clear(),
      Hive.box<ObjectScanRecord>(HiveBoxes.objectScans).clear(),
    ]);
  }

  /// Call from `tearDownAll`.
  Future<void> close() async {
    await Hive.deleteFromDisk();
    if (await _folder.exists()) await _folder.delete(recursive: true);
  }
}
