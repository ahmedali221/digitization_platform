import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/wall_status.dart';
import '../../domain/repositories/grid_capture_repository.dart';

/// Backs [GridCaptureRepository] with the same in-memory site tree
/// [SiteRepository] already owns, so grid edits made here show up
/// immediately on the site overview screen and vice versa.
class FakeGridCaptureRepository implements GridCaptureRepository {
  FakeGridCaptureRepository(this._siteRepository);

  final SiteRepository _siteRepository;

  @override
  WallEntity? getWall(String floorId, String wallId) =>
      _siteRepository.findWall(floorId, wallId);

  @override
  void createGrid(String floorId, String wallId, int rows, int cols) {
    _siteRepository.updateWall(
      floorId,
      wallId,
      (current) => current.copyWith(
        grid: GridState(
          rows: rows,
          cols: cols,
          cells: List.generate(rows * cols, (_) => const GridCell()),
        ),
      ),
    );
  }

  @override
  void capturePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath,
  ) {
    _siteRepository.updateWall(floorId, wallId, (current) {
      final grid = current.grid;
      if (grid == null) return current;
      return current.copyWith(grid: grid.withShotAdded(cellIndex, filePath));
    });
  }

  @override
  void saveFull(String floorId, String wallId) {
    _siteRepository.updateWall(floorId, wallId, (current) {
      final grid = current.grid;
      if (grid == null || !grid.isComplete) return current;
      return current.copyWith(
        status: WallStatus.captured,
        lastCapture: 'just now',
      );
    });
  }

  @override
  void savePartial(String floorId, String wallId) {
    _siteRepository.updateWall(floorId, wallId, (current) {
      final grid = current.grid;
      if (grid == null) return current;
      if (grid.isComplete) {
        return current.copyWith(
          status: WallStatus.captured,
          lastCapture: 'just now',
        );
      }
      final anyPhotos = grid.filledCount > 0;
      return current.copyWith(
        status: anyPhotos ? WallStatus.inProgress : WallStatus.notStarted,
        lastCapture: 'just now',
      );
    });
  }

  @override
  Stream<WallEntity?> watchWall(String floorId, String wallId) {
    return _siteRepository.watchSites().map(
      (_) => _siteRepository.findWall(floorId, wallId),
    );
  }
}
