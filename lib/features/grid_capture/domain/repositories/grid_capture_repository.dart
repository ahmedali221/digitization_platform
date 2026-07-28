import '../../../../core/domain/entities/wall.dart';

/// Storage-watchdog verdict (FLUTTER_MOBILE_PLAN.md Phase 7) — [low] warns
/// but still allows starting; [critical] blocks starting a new session
/// entirely, so a capture never fails mid-session from running out of
/// space.
enum StorageCheckResult { sufficient, low, critical }

/// Outcome of [GridCaptureRepository.reshapeGrid] — [blockedShrinkHasPhotos]
/// mirrors the web dashboard's `WallGridService::assertRemovedCellsEmpty`
/// rule: a resize that would drop a cell that already has photos is refused
/// rather than silently discarding captured work.
enum GridReshapeResult { applied, blockedShrinkHasPhotos }

/// Contract for the grid-init / grid-capture / camera / coverage-review
/// session (FLUTTER_MOBILE_PLAN.md Phases 3-4). Reads/writes the same
/// site/floor/wall tree [SiteRepository] owns — this narrower interface only
/// exposes the operations the capture flow itself needs (CLAUDE.md's ISP
/// rule), rather than depending on the full site tree contract.
abstract class GridCaptureRepository {
  WallEntity? getWall(String floorId, String wallId);

  /// Checked before a brand-new grid is created (not before every shot —
  /// each shot writes at most one photo, which either succeeds or fails
  /// outright; the watchdog exists to stop the operator from *starting* a
  /// session storage can't hold).
  Future<StorageCheckResult> checkStorageForNewSession(int cellCount);

  void createGrid(String floorId, String wallId, int rows, int cols);

  /// Changes an already-initialized grid's dimensions in place, keeping the
  /// photos already captured in any cell that still exists after the
  /// resize (row/col < the new [rows]/[cols]) — an operator who over- or
  /// under-sized the grid at init time doesn't need to lose captured work
  /// or restart the wall to fix it. Returns the wall with the reshaped grid
  /// already applied so callers can update their own state directly (same
  /// reason [capturePhoto] does: [watchWall] never re-emits for this).
  ({GridReshapeResult result, WallEntity? wall}) reshapeGrid(
    String floorId,
    String wallId,
    int rows,
    int cols,
  );

  /// [filePath] is where the shot was already saved on disk (by the local
  /// data source, before this call) — the repository only records it.
  /// [sha256] and [shot] are only meaningful for the real implementation's
  /// sync manifest; the fake ignores them.
  ///
  /// Returns the wall with the new shot already reflected in its [grid], so
  /// callers can update their own state directly — [watchWall]'s stream only
  /// re-emits on changes [SiteRepository] itself watches (site/wall-status),
  /// which a capture never touches, so it can't be relied on to notice this.
  WallEntity? capturePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath, {
    String? sha256,
    int? shot,
  });

  /// Removes one captured photo from the cell and from on-device storage.
  /// Returns the wall with the updated grid so the active camera screen can
  /// refresh immediately without waiting for [watchWall] to emit.
  Future<WallEntity?> deletePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath,
  );

  /// Only meaningful once every cell has at least one photo — marks the wall
  /// `captured` and awaiting admin review.
  void saveFull(String floorId, String wallId);

  /// Always available: promotes the wall to `in_progress`/`captured`/back to
  /// `not_started` depending on how much of the grid has photos, so a
  /// session can be paused without losing progress.
  void savePartial(String floorId, String wallId);

  Stream<WallEntity?> watchWall(String floorId, String wallId);
}
