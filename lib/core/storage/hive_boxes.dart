import 'package:hive_flutter/hive_flutter.dart';

import '../../features/grid_capture/data/models/capture_session_record.dart';
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
  static const String unassigned = 'unassigned';
  static const String syncQueue = 'sync_queue';
  static const String fieldNotes = 'field_notes';
  static const String idMappings = 'id_mappings';
  static const String device = 'device';
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
  ]);
}
