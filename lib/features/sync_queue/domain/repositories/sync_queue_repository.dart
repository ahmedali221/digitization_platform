import '../entities/sync_item.dart';

/// Contract for the pending-upload queue shown on the sync screen. The real
/// implementation backs this with the `workmanager`/Hive upload queue
/// (FLUTTER_MOBILE_PLAN.md Phase 7) — this UI-first pass only needs the read
/// stream plus a way to re-enqueue a failed item.
abstract class SyncQueueRepository {
  Stream<List<SyncItem>> watchQueue();

  void retry(String id);

  /// Permanently removes a queue item without attempting to sync it — used
  /// once an item's underlying wall has been recovered through
  /// [UnassignedWallRepository.migrateOrphanedGridCapture], making the
  /// original (unsyncable) entry redundant.
  Future<void> discard(String id);
}
