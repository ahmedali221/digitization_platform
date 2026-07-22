import '../../../../core/domain/entities/wall.dart';

/// Contract for the grid-init / grid-capture / camera / coverage-review
/// session (FLUTTER_MOBILE_PLAN.md Phases 3-4). Reads/writes the same
/// site/floor/wall tree [SiteRepository] owns — this narrower interface only
/// exposes the operations the capture flow itself needs (CLAUDE.md's ISP
/// rule), rather than depending on the full site tree contract.
abstract class GridCaptureRepository {
  WallEntity? getWall(String floorId, String wallId);

  void createGrid(String floorId, String wallId, int rows, int cols);

  /// [filePath] is where the shot was already saved on disk (by the local
  /// data source, before this call) — the repository only records it.
  void capturePhoto(
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
