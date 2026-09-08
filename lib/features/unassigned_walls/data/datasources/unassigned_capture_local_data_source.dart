import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../models/unassigned_capture_record.dart';

/// Hive CRUD for local-id (unassigned) wall captures' sync/resolution
/// bookkeeping (`syncStatus`/`resolvedWallId`/`createdAt`) — photos
/// themselves are captured through the normal grid-init/grid-capture
/// pipeline (`GridCaptureLocalDataSource`/`CaptureSessionLocalDataSource`)
/// against the `local_id` directly. [recordShot] remains only for
/// [UnassignedWallRepository.migrateOrphanedGridCapture]'s legacy recovery
/// path.
class UnassignedCaptureLocalDataSource {
  Box<UnassignedCaptureRecord> get _box =>
      Hive.box<UnassignedCaptureRecord>(HiveBoxes.unassignedCaptures);

  UnassignedCaptureRecord? get(String localId) => _box.get(localId);

  List<UnassignedCaptureRecord> all() => _box.values.toList();

  Stream<List<UnassignedCaptureRecord>> watchAll() async* {
    yield all();
    yield* _box.watch().map((_) => all());
  }

  Future<void> put(UnassignedCaptureRecord record) =>
      _box.put(record.localId, record);

  Future<UnassignedCaptureRecord> ensure({
    required String localId,
    required String siteId,
    required String floorId,
  }) async {
    final existing = _box.get(localId);
    if (existing != null) return existing;
    final record = UnassignedCaptureRecord(
      localId: localId,
      siteId: siteId,
      floorId: floorId,
      createdAt: DateTime.now(),
    );
    await _box.put(localId, record);
    return record;
  }

  /// Used only by [UnassignedWallRepository.migrateOrphanedGridCapture] to
  /// recover photos out of a stale, pre-fix `CaptureSessionRecord`.
  Future<UnassignedCaptureRecord> recordShot({
    required String localId,
    required String filePath,
    required String sha256,
  }) async {
    final record = _box.get(localId);
    if (record == null) {
      throw StateError('No capture record for $localId — call ensure() first.');
    }
    record.shots = [...record.shots, filePath];
    record.checksums = [...record.checksums, sha256];
    await record.save();
    return record;
  }
}
