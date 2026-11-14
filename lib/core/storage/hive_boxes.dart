import 'package:hive_flutter/hive_flutter.dart';

import '../../features/follow_up/data/models/follow_up_upload_record.dart';
import '../../features/grid_capture/data/models/capture_session_record.dart';
import '../../features/grid_capture/data/models/cell_quality_record.dart';
import '../../features/object_capture/data/models/object_capture_record.dart';
import '../../features/object_capture/data/models/object_scan_record.dart';
import '../../features/sync_queue/data/models/sync_queue_item_record.dart';
import '../data/models/floor_package_record.dart';
import '../data/models/id_mapping_record.dart';
import '../data/models/site_package_record.dart';
import '../data/models/wall_status_record.dart';

/// Box-name constants for every Hive box in FLUTTER_MOBILE_PLAN.md §3, plus
/// `device` (Phase 0's stable device UUID, not one of §3's named boxes but
/// required by its own task list).
class HiveBoxes {
  const HiveBoxes._();

  static const String sites = 'sites';
  static const String floors = 'floors';
  static const String wallStatus = 'wall_status';
  static const String sessions = 'sessions';

  /// Walls and objects added on this phone. Named for the dashboard queue
  /// they used to wait in; renaming it would strand what phones already hold.
  static const String unassigned = 'unassigned';
  static const String syncQueue = 'sync_queue';
  static const String fieldNotes = 'field_notes';
  static const String idMappings = 'id_mappings';
  static const String device = 'device';
  static const String settings = 'settings';
  static const String followUpUploads = 'follow_up_uploads';
  static const String objectCaptures = 'object_captures';
  static const String objectScans = 'object_scans';

  /// Bookkeeping for the unassigned queue, which the app no longer uses.
  /// Everything it held that still matters lives in [idMappings] and
  /// [sessions], so the box is deleted rather than read.
  static const String _retiredUnassignedCaptures = 'unassigned_captures';
}

/// Registers every `@HiveType` adapter and opens every box. Called once at
/// boot, before `setupDependencies()` — repositories assume boxes are
/// already open.
Future<void> registerAdaptersAndOpenBoxes() async {
  Hive.registerAdapter(SitePackageRecordAdapter());
  Hive.registerAdapter(FloorPackageRecordAdapter());
  Hive.registerAdapter(WallStatusRecordAdapter());
  Hive.registerAdapter(IdMappingRecordAdapter());
  Hive.registerAdapter(CapturePhotoRecordAdapter());
  Hive.registerAdapter(CaptureCellRecordAdapter());
  Hive.registerAdapter(CaptureSessionRecordAdapter());
  Hive.registerAdapter(SyncQueueItemRecordAdapter());
  Hive.registerAdapter(CellQualityRecordAdapter());
  Hive.registerAdapter(NeighbourQualityRecordAdapter());
  Hive.registerAdapter(ShotQualityScoreRecordAdapter());
  Hive.registerAdapter(FollowUpUploadRecordAdapter());
  Hive.registerAdapter(ObjectPhotoRecordAdapter());
  Hive.registerAdapter(ObjectCaptureRecordAdapter());
  Hive.registerAdapter(ScanShotRecordAdapter());
  Hive.registerAdapter(ObjectScanRecordAdapter());

  await Future.wait([
    Hive.openBox<SitePackageRecord>(HiveBoxes.sites),
    Hive.openBox<FloorPackageRecord>(HiveBoxes.floors),
    Hive.openBox<WallStatusRecord>(HiveBoxes.wallStatus),
    Hive.openBox<CaptureSessionRecord>(HiveBoxes.sessions),
    Hive.openBox(HiveBoxes.unassigned),
    Hive.openBox<SyncQueueItemRecord>(HiveBoxes.syncQueue),
    Hive.openBox(HiveBoxes.fieldNotes),
    Hive.openBox<IdMappingRecord>(HiveBoxes.idMappings),
    Hive.openBox(HiveBoxes.device),
    Hive.openBox(HiveBoxes.settings),
    Hive.openBox<FollowUpUploadRecord>(HiveBoxes.followUpUploads),
    Hive.openBox<ObjectCaptureRecord>(HiveBoxes.objectCaptures),
    Hive.openBox<ObjectScanRecord>(HiveBoxes.objectScans),
    Hive.deleteBoxFromDisk(HiveBoxes._retiredUnassignedCaptures),
  ]);
}
