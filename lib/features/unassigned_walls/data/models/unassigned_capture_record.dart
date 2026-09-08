import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'unassigned_capture_record.g.dart';

/// A local-id wall's sync/resolution bookkeeping — box `unassigned_captures`,
/// keyed by [localId]. Separate from the plain
/// `{floorId, title, notes, createdAt}` map `SiteLocalDataSource` already
/// keeps in the `unassigned` box for the wall-stub itself; this record
/// tracks the metadata-sync/resolution lifecycle (FLUTTER_MOBILE_PLAN.md §5)
/// — actual photos live in `CaptureSessionRecord`, keyed by the same
/// `local_id`, via the normal grid-init/grid-capture pipeline.
@HiveType(typeId: HiveTypeIds.unassignedCaptureRecord)
class UnassignedCaptureRecord extends HiveObject {
  UnassignedCaptureRecord({
    required this.localId,
    required this.siteId,
    required this.floorId,
    this.shots = const [],
    this.checksums = const [],
    required this.createdAt,
    this.syncStatus = 'notSynced',
    this.lastSyncedAt,
    this.resolvedWallId,
  });

  @HiveField(0)
  final String localId;

  @HiveField(1)
  final String siteId;

  @HiveField(2)
  final String floorId;

  /// Legacy flat, capture-order shot file paths — no longer written by the
  /// normal capture flow (photos go through `CaptureSessionRecord` via the
  /// grid-init/grid-capture pipeline instead). Only still populated by
  /// [UnassignedWallRepository.migrateOrphanedGridCapture]'s recovery path.
  @HiveField(3)
  List<String> shots;

  /// Parallel to [shots] — sha256 of each file.
  @HiveField(4)
  List<String> checksums;

  @HiveField(5)
  final DateTime createdAt;

  /// 'notSynced' | 'awaitingResolution' | 'resolved'.
  @HiveField(6)
  String syncStatus;

  @HiveField(7)
  DateTime? lastSyncedAt;

  @HiveField(8)
  String? resolvedWallId;
}
