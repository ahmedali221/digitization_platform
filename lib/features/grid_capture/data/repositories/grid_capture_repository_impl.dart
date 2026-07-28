import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../datasources/capture_session_local_data_source.dart';
import '../datasources/grid_capture_local_data_source.dart';
import '../models/capture_session_record.dart';

/// Real, Hive+file-backed [GridCaptureRepository]. Wall status still lives
/// entirely in [SiteRepository] (via `updateWall`) — this repository only
/// owns the *local capture round* (per-wall grid + cell photos) and
/// overlays it onto whatever [SiteRepository] returns, exactly as the fake
/// this replaces does with its in-memory grid.
class GridCaptureRepositoryImpl implements GridCaptureRepository {
  GridCaptureRepositoryImpl({
    required SiteRepository siteRepository,
    required CaptureSessionLocalDataSource sessionLocal,
    required GridCaptureLocalDataSource fileLocal,
    required DirectoryManager directoryManager,
    required SyncEnqueuer syncEnqueuer,
  }) : _siteRepository = siteRepository,
       _sessionLocal = sessionLocal,
       _fileLocal = fileLocal,
       _directoryManager = directoryManager,
       _syncEnqueuer = syncEnqueuer;

  /// Conservative flat estimate — a proper per-device average (the plan's
  /// "based on the most recently completed session") would need its own
  /// running-average tracking; this stays honestly simple until real field
  /// data shows it needs to be smarter.
  static const _bytesPerPhotoEstimate = 6 * 1024 * 1024;

  final SiteRepository _siteRepository;
  final CaptureSessionLocalDataSource _sessionLocal;
  final GridCaptureLocalDataSource _fileLocal;
  final DirectoryManager _directoryManager;
  final SyncEnqueuer _syncEnqueuer;

  @override
  WallEntity? getWall(String floorId, String wallId) =>
      _overlaySession(_siteRepository.findWall(floorId, wallId));

  @override
  Stream<WallEntity?> watchWall(String floorId, String wallId) {
    return _siteRepository.watchSites().map(
      (_) => _overlaySession(_siteRepository.findWall(floorId, wallId)),
    );
  }

  WallEntity? _overlaySession(WallEntity? wall) {
    if (wall == null) return null;
    final session = _sessionLocal.get(wall.id);
    if (session == null) return wall;

    final cells = List.generate(session.gridRows * session.gridCols, (i) {
      final row = i ~/ session.gridCols;
      final col = i % session.gridCols;
      final cell = session.cells.firstWhere(
        (c) => c.row == row && c.col == col,
        orElse: () => CaptureCellRecord(row: row, col: col, photos: []),
      );
      return GridCell(shotPaths: cell.photos.map((p) => p.file).toList());
    });

    return wall.copyWith(
      grid: GridState(
        rows: session.gridRows,
        cols: session.gridCols,
        cells: cells,
      ),
    );
  }

  @override
  Future<StorageCheckResult> checkStorageForNewSession(int cellCount) async {
    final estimated = cellCount * _bytesPerPhotoEstimate;
    final free = await _directoryManager.freeSpaceBytes();
    if (free < estimated) return StorageCheckResult.critical;
    if (free < estimated * 2) return StorageCheckResult.low;
    return StorageCheckResult.sufficient;
  }

  @override
  void createGrid(String floorId, String wallId, int rows, int cols) {
    final siteId = _siteIdForFloor(floorId);
    _sessionLocal.put(
      CaptureSessionRecord(
        sessionId: wallId,
        wallId: wallId,
        floorId: floorId,
        siteId: siteId ?? '',
        gridRows: rows,
        gridCols: cols,
        cells: List.generate(
          rows * cols,
          (i) => CaptureCellRecord(row: i ~/ cols, col: i % cols, photos: []),
        ),
        state: 'inProgress',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  WallEntity? capturePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath, {
    String? sha256,
    int? shot,
  }) {
    var session = _sessionLocal.get(wallId);
    if (session == null) {
      // A wall whose grid was already initialized server-side (or by a
      // prior local session) skips grid-init entirely (Phase 3) — the
      // first shot lazily creates the local session record from the grid
      // dimensions SiteRepository already knows about.
      final grid = _siteRepository.findWall(floorId, wallId)?.grid;
      if (grid == null) return null;
      final siteId = _siteIdForFloor(floorId);
      session = CaptureSessionRecord(
        sessionId: wallId,
        wallId: wallId,
        floorId: floorId,
        siteId: siteId ?? '',
        gridRows: grid.rows,
        gridCols: grid.cols,
        cells: List.generate(
          grid.rows * grid.cols,
          (i) => CaptureCellRecord(
            row: i ~/ grid.cols,
            col: i % grid.cols,
            photos: [],
          ),
        ),
        state: 'inProgress',
        createdAt: DateTime.now(),
      );
    }

    final row = cellIndex ~/ session.gridCols;
    final col = cellIndex % session.gridCols;
    session.addPhotoAt(
      row,
      col,
      CapturePhotoRecord(
        file: filePath,
        sha256: sha256 ?? '',
        shot: shot ?? (session.cellAt(row, col).photos.length + 1),
        capturedAt: DateTime.now(),
      ),
    );
    // A new photo on any cell reopens a previously-completed local round —
    // mirrors §4's done -> captured server-side rule, applied locally too.
    session.state = 'inProgress';
    session.completedAt = null;
    _sessionLocal.put(session);
    return _overlaySession(_siteRepository.findWall(floorId, wallId));
  }

  @override
  Future<WallEntity?> deletePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath,
  ) async {
    final session = _sessionLocal.get(wallId);
    if (session == null ||
        cellIndex < 0 ||
        cellIndex >= session.gridRows * session.gridCols) {
      return getWall(floorId, wallId);
    }

    final row = cellIndex ~/ session.gridCols;
    final col = cellIndex % session.gridCols;
    if (!session.removePhotoAt(row, col, filePath)) {
      return getWall(floorId, wallId);
    }

    session.state = 'inProgress';
    session.completedAt = null;
    await _sessionLocal.put(session);

    try {
      await _fileLocal.deleteShot(wallId: wallId, filePath: filePath);
    } catch (error) {
      // The session record is authoritative. A failed best-effort cleanup
      // must not make the discarded image reappear in the capture UI/sync.
      debugPrint(
        'GridCaptureRepositoryImpl: failed to delete photo file $filePath: '
        '$error',
      );
    }

    return _overlaySession(_siteRepository.findWall(floorId, wallId));
  }

  @override
  void saveFull(String floorId, String wallId) {
    final session = _sessionLocal.get(wallId);
    if (session == null || !session.isComplete) return;
    unawaited(_guardedFinalize(session, floorId, wallId, completed: true));
  }

  @override
  void savePartial(String floorId, String wallId) {
    final session = _sessionLocal.get(wallId);
    if (session == null) return;
    unawaited(
      _guardedFinalize(session, floorId, wallId, completed: session.isComplete),
    );
  }

  /// [saveFull]/[savePartial] are synchronous per the existing
  /// [GridCaptureRepository] contract (the fake this replaces never needed
  /// to be async) — this catches and surfaces manifest-write/enqueue
  /// failures via [debugPrint] rather than letting them become an unhandled
  /// async error, since the void signature gives callers nothing to await.
  Future<void> _guardedFinalize(
    CaptureSessionRecord session,
    String floorId,
    String wallId, {
    required bool completed,
  }) async {
    try {
      await _finalizeSession(session, floorId, wallId, completed: completed);
    } catch (e) {
      debugPrint(
        'GridCaptureRepositoryImpl: failed to finalize session for $wallId: $e',
      );
    }
  }

  Future<void> _finalizeSession(
    CaptureSessionRecord session,
    String floorId,
    String wallId, {
    required bool completed,
  }) async {
    // Self-heals a session created while SiteMapper's site-id resolution
    // was broken (it read a field the bundle never carries and silently
    // fell back to ''), which would otherwise 422 forever at sync time.
    if (session.siteId.isEmpty) {
      session.siteId = _siteIdForFloor(floorId) ?? session.siteId;
    }
    session.state = completed ? 'completed' : 'inProgress';
    session.completedAt = completed ? DateTime.now() : null;
    await _sessionLocal.put(session);

    await _fileLocal.writeManifest(
      wallId: wallId,
      manifest: {
        'grid_rows': session.gridRows,
        'grid_cols': session.gridCols,
        'cells': session.cells
            .map(
              (c) => {
                'row': c.row,
                'col': c.col,
                'photos': c.photos
                    .map((p) => {'file': p.file, 'sha256': p.sha256})
                    .toList(),
              },
            )
            .toList(),
        'completed': completed,
      },
    );

    _siteRepository.updateWall(floorId, wallId, (current) {
      if (completed) {
        return current.copyWith(
          status: WallStatus.captured,
          lastCapture: 'just now',
        );
      }
      final anyPhotos = session.filledCellCount > 0;
      return current.copyWith(
        status: anyPhotos ? WallStatus.inProgress : WallStatus.notStarted,
        lastCapture: 'just now',
      );
    });

    final wallName = _siteRepository.findWall(floorId, wallId)?.name ?? wallId;
    await _syncEnqueuer.enqueueSession(
      wallId: wallId,
      siteId: session.siteId,
      displayName: wallName,
    );
  }

  String? _siteIdForFloor(String floorId) {
    final floor = _siteRepository.findFloor(floorId);
    if (floor == null) return null;
    final building = _siteRepository.findBuilding(floor.buildingId);
    return building?.siteId;
  }
}
