import '../entities/unassigned_wall.dart';

/// Contract for capturing and syncing walls found before a room/zone
/// assignment was known (FLUTTER_MOBILE_PLAN.md Phase 5). Photos are kept
/// as a flat, ungridded list on-device — grid capture against a `local_id`
/// isn't supported server-side (Section 5/8 of the plan) — until
/// [checkResolution] finds a real `wall_id`, at which point
/// [promoteToRealWall] hands the flat shots off to the normal, working
/// grid-capture/sync-queue pipeline.
abstract class UnassignedWallRepository {
  Stream<List<UnassignedWall>> watchUnassignedWalls();

  UnassignedWall? findByLocalId(String localId);

  /// Appends one already-saved shot (see the capture cubit, which saves the
  /// file first — mirroring `GridCaptureRepository.capturePhoto`'s
  /// filePath/sha256 convention) to [localId]'s flat photo list.
  Future<void> appendShot(String localId, String filePath, String sha256);

  /// Removes one previously-appended shot from [localId]'s flat photo list.
  Future<void> removeShot(String localId, String filePath);

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

  /// Grid-ifies [localId]'s flat shots (1 row × N columns) into a real
  /// `CaptureSessionRecord` against its resolved wall, then enqueues it
  /// through the existing `SyncEnqueuer`/`SyncQueueRunner` pipeline.
  /// No-op if [localId] hasn't been resolved yet.
  Future<void> promoteToRealWall(String localId);
}
