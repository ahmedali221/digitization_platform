import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'unassigned_capture_record.g.dart';

/// A local-id wall's flat (no-grid) capture session — box
/// `unassigned_captures`, keyed by [localId]. Separate from the plain
/// `{floorId, title, notes, createdAt}` map `SiteLocalDataSource` already
/// keeps in the `unassigned` box for the wall-stub itself; this record only
/// tracks the photos and their sync lifecycle (FLUTTER_MOBILE_PLAN.md §5).
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

  /// Flat, capture-order shot file paths — no row/col, per Phase 5's "treat
  /// photos as a flat list (no grid)" guidance for unresolved local walls.
  @HiveField(3)
  List<String> shots;

  /// Parallel to [shots] — sha256 of each file, needed once
  /// [UnassignedWallRepository.promoteToRealWall] grid-ifies these into a
  /// real `CaptureSessionRecord`.
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
