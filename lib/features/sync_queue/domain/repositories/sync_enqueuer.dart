/// Narrow port `grid_capture` depends on to hand a finished/paused capture
/// round off to the upload pipeline (CLAUDE.md's ISP rule — it doesn't need
/// the rest of [SyncQueueRepository]'s surface). Implemented by
/// [SyncQueueRepositoryImpl] alongside the full repository.
abstract class SyncEnqueuer {
  Future<void> enqueueSession({
    required String wallId,
    required String siteId,
    required String displayName,
  });
}
