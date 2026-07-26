import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'capture_session_record.g.dart';

@HiveType(typeId: HiveTypeIds.capturePhotoRecord)
class CapturePhotoRecord {
  CapturePhotoRecord({
    required this.file,
    required this.sha256,
    required this.shot,
    required this.capturedAt,
  });

  @HiveField(0)
  final String file;

  @HiveField(1)
  final String sha256;

  @HiveField(2)
  final int shot;

  @HiveField(3)
  final DateTime capturedAt;
}

@HiveType(typeId: HiveTypeIds.captureCellRecord)
class CaptureCellRecord {
  CaptureCellRecord({
    required this.row,
    required this.col,
    required this.photos,
  });

  @HiveField(0)
  final int row;

  @HiveField(1)
  final int col;

  @HiveField(2)
  final List<CapturePhotoRecord> photos;

  CaptureCellRecord withPhotoAdded(CapturePhotoRecord photo) =>
      CaptureCellRecord(row: row, col: col, photos: [...photos, photo]);
}

/// One wall's local capture progress on this device — the durable backing
/// store for `WallEntity.grid.cells[].shotPaths` (the mapped/read-only
/// entity itself never persists local file paths; this record does). Box
/// `sessions` (FLUTTER_MOBILE_PLAN.md §3), keyed by [wallId] — this app
/// only ever has one active local capture round per wall at a time
/// (including a later top-up round on an already-`done` wall, per §4's
/// `done -> captured` rule), so the wall id itself is a stable, sufficient
/// key; [sessionId] equals [wallId] and exists as its own field only so
/// sync-queue records (which reference a session, not a wall, in the
/// abstract) don't need to special-case that equivalence.
///
/// `state` tracks local completeness only ("did the operator finish
/// shooting this grid") — sync/upload lifecycle is a separate concern
/// owned by the `sync_queue` box (see SyncQueueItemRecord). A fresh top-up
/// round reopens the same record (`state` back to `inProgress`,
/// `completedAt` cleared) rather than creating a new one.
@HiveType(typeId: HiveTypeIds.captureSessionRecord)
class CaptureSessionRecord extends HiveObject {
  CaptureSessionRecord({
    required this.sessionId,
    required this.wallId,
    required this.floorId,
    required this.siteId,
    required this.gridRows,
    required this.gridCols,
    required this.cells,
    required this.state,
    required this.createdAt,
    this.completedAt,
    this.serverSessionId,
  });

  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String wallId;

  @HiveField(2)
  final String floorId;

  /// Mutable (unlike [sessionId]/[wallId]/[floorId]) so a session created
  /// while `SiteMapper` had the site-id-resolution bug can be self-healed
  /// on the next finalize rather than staying permanently unsyncable.
  @HiveField(3)
  String siteId;

  @HiveField(4)
  int gridRows;

  @HiveField(5)
  int gridCols;

  @HiveField(6)
  List<CaptureCellRecord> cells;

  /// 'inProgress' | 'completed'.
  @HiveField(7)
  String state;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  DateTime? completedAt;

  /// The id `POST /sync/sessions` returned for the current registration —
  /// null until registered, overwritten on each fresh registration (a
  /// top-up round re-registers the same wall).
  @HiveField(10)
  String? serverSessionId;

  int get filledCellCount => cells.where((c) => c.photos.isNotEmpty).length;

  bool get isComplete => filledCellCount == cells.length;

  CaptureCellRecord cellAt(int row, int col) =>
      cells.firstWhere((c) => c.row == row && c.col == col);

  void addPhotoAt(int row, int col, CapturePhotoRecord photo) {
    cells = cells
        .map((c) => c.row == row && c.col == col ? c.withPhotoAdded(photo) : c)
        .toList();
  }
}
