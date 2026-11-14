import '../entities/sync_item_kind.dart';

/// Narrow port a capture feature depends on to hand a finished or paused
/// capture off to the upload pipeline (CLAUDE.md's ISP rule — it doesn't
/// need the rest of [SyncQueueRepository]'s surface). Implemented by
/// [SyncQueueRepositoryImpl] alongside the full repository.
abstract class SyncEnqueuer {
  /// [wallId] is the id this phone knows the wall by, `local_` ids included:
  /// an item created here is registered with the server as part of its
  /// upload, so there is nothing to resolve first.
  Future<void> enqueueCapture({
    required String wallId,
    required String siteId,
    required String displayName,
    required SyncItemKind kind,
  });
}
