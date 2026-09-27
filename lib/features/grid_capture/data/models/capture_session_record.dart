import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';
import 'cell_quality_record.dart';

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
    this.quality,
    this.qualityOverridden = false,
  });

  @HiveField(0)
  final int row;

  @HiveField(1)
  final int col;

  @HiveField(2)
  final List<CapturePhotoRecord> photos;

  /// Capture Quality Indicator result for this cell's current shot — null
  /// until Tier 1 has run at least once. Local-only (see CaptureAnalyzer);
  /// never part of the sync/upload manifest.
  @HiveField(3)
  final CellQualityRecord? quality;

  /// The operator explicitly chose to keep this shot despite a red/orange
  /// score. Deliberately a separate field from [quality] (not a field on
  /// [CellQualityRecord] itself): [quality] gets wholesale-replaced by
  /// every fresh analysis (including a neighbour-triggered rescore that
  /// doesn't touch this cell's own photo), while this flag must survive
  /// that and only ever change via [withPhotoAdded]/[withQualityOverride].
  @HiveField(4)
  final bool qualityOverridden;

  CaptureCellRecord withPhotoAdded(CapturePhotoRecord photo) => CaptureCellRecord(
    row: row,
    col: col,
    photos: [...photos, photo],
    quality: quality,
    qualityOverridden: false,
  );

  CaptureCellRecord withQuality(CellQualityRecord result) => CaptureCellRecord(
    row: row,
    col: col,
    photos: photos,
    quality: result,
    qualityOverridden: qualityOverridden,
  );

  CaptureCellRecord withQualityOverride(bool overridden) => CaptureCellRecord(
    row: row,
    col: col,
    photos: photos,
    quality: quality,
    qualityOverridden: overridden,
  );
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

  // [cells] is always built row-major, sized gridRows*gridCols (see
  // _newSessionRecord/reshapeGrid in GridCaptureRepositoryImpl), so a cell's
  // position in the list is its index directly — a firstWhere scan (or,
  // worse, rebuilding the whole list to patch one cell) costs O(cells) on
  // every single photo, and grid_capture's own performance audit found that
  // compounding into a real, measured slowdown as a session's photo count
  // grows (each mutation preceded a full-record Hive write whose cost also
  // scales with how much the session has accumulated so far).
  int _indexOf(int row, int col) => row * gridCols + col;

  CaptureCellRecord cellAt(int row, int col) => cells[_indexOf(row, col)];

  void addPhotoAt(int row, int col, CapturePhotoRecord photo) {
    final index = _indexOf(row, col);
    cells[index] = cells[index].withPhotoAdded(photo);
  }

  bool removePhotoAt(int row, int col, String filePath) {
    final index = _indexOf(row, col);
    final cell = cells[index];
    if (!cell.photos.any((photo) => photo.file == filePath)) return false;

    // Matches the pre-existing behaviour this replaces: removing a photo
    // resets quality/qualityOverridden too (defaults, left unset below) —
    // deletePhoto's caller always re-runs analysis afterwards anyway.
    cells[index] = CaptureCellRecord(
      row: cell.row,
      col: cell.col,
      photos: cell.photos.where((photo) => photo.file != filePath).toList(),
    );
    return true;
  }
}
