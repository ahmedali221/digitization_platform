import '../entities/unassigned_wall.dart';

/// Contract for capturing and syncing walls found before a room/zone
/// assignment was known (FLUTTER_MOBILE_PLAN.md Phase 5). Photos are captured
/// through the normal grid-init/grid-capture pipeline against the `local_id`
/// itself (`GridCaptureRepository`, same as any real wall) — the backend
/// still only accepts a resolved `wall_id` (Section 5/8 of the plan), so
/// nothing here ever enqueues a session until [checkResolution] finds one
/// and [promoteToRealWall] re-keys the already-captured session onto it.
abstract class UnassignedWallRepository {
  Stream<List<UnassignedWall>> watchUnassignedWalls();

  UnassignedWall? findByLocalId(String localId);

  /// `POST /sync/unassigned` — registers/refreshes this capture's metadata
  /// server-side. Idempotent on `(local_id, site_id)`. [siteId] overrides the
  /// site normally derived from the wall's floor — used when recovering a
  /// wall whose cached floor→site mapping is stale (see
  /// [migrateOrphanedGridCapture]).
  Future<void> syncMetadata(String localId, {String? siteId});

  /// Recovers a wall captured through the old grid-capture pipeline before
  /// it was routed to this feature (pre-fix local-id walls, left stuck in
  /// the sync queue with a "wall id must be an integer" 422): copies its
  /// already-taken photos out of the stale `CaptureSessionRecord` and into
  /// [localId]'s flat capture record, so it can go through the normal
  /// [syncMetadata]/[checkResolution]/[promoteToRealWall] flow without the
  /// operator retaking anything. No-op if there's no such leftover session.
  Future<void> migrateOrphanedGridCapture(String localId);

  /// `GET /sync/mappings` for this device — persists a resolved `wall_id`
  /// via `IdMappingRecord` if one now exists for [localId].
  Future<void> checkResolution(String localId);

  /// Calls [checkResolution] for every wall still awaiting resolution — one
  /// `GET /sync/mappings` round-trip covers all of them. Wired to fire on
  /// reconnect (`wireForegroundSyncOnReconnect`), alongside the existing
  /// `SyncQueueRunner.drainAll()` call.
  Future<void> checkAllResolutions();

  /// Re-keys [localId]'s already-captured `CaptureSessionRecord` onto its
  /// resolved wall id, then enqueues it through the existing
  /// `SyncEnqueuer`/`SyncQueueRunner` pipeline. No-op if [localId] hasn't
  /// been resolved yet or has no captured session.
  Future<void> promoteToRealWall(String localId);
}
