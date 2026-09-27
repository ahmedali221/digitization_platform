import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/entities/capture_quality.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../../domain/services/capture_analyzer.dart';
import 'capture_session_state.dart';

/// Fixed rows x cols choices offered on the grid-init screen, in addition to
/// the custom stepper.
typedef GridPreset = ({int rows, int cols, String label});

const List<GridPreset> kGridPresets = [
  (rows: 2, cols: 2, label: '2 × 2'),
  (rows: 3, cols: 3, label: '3 × 3'),
  (rows: 4, cols: 3, label: '4 × 3'),
];

const _maxGridDimension = 20;
const _maxGridCells = 400;

/// Backs the grid-init, grid-capture, camera-capture, and coverage-review
/// screens — one linear capture session, so one cubit (rather than a cubit
/// per screen per CLAUDE.md's usual "one cubit per screen" default, which
/// would otherwise force each screen to re-derive the others' in-flight
/// state). Each screen provides its own instance and calls [init]; the
/// underlying [GridCaptureRepository] stream is the real source of truth for
/// wall/grid data, so a freshly-created instance always picks up whatever
/// the previous screen just wrote.
class CaptureSessionCubit extends Cubit<CaptureSessionState> {
  CaptureSessionCubit(
    this._repository,
    this._localDataSource,
  ) : super(const CaptureSessionLoading());

  final GridCaptureRepository _repository;
  final GridCaptureLocalDataSource _localDataSource;
  String _floorId = '';
  String _wallId = '';
  StreamSubscription<WallEntity?>? _subscription;

  /// Set by [openCell] when called before the wall stream's first event
  /// arrives (e.g. camera-capture's `..init()..openCell(initialCell)`
  /// cascade) — [_onWallChanged] applies it to the first [CaptureSessionLoaded]
  /// it constructs, since that constructor call would otherwise silently
  /// drop an [openCell] that landed while still [CaptureSessionLoading].
  int? _pendingActiveCellId;

  void init(String floorId, String wallId) {
    _floorId = floorId;
    _wallId = wallId;
    emit(const CaptureSessionLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchWall(floorId, wallId)
        .listen(
          _onWallChanged,
          onError: (Object error) =>
              emit(CaptureSessionError(error.toString())),
        );
  }

  /// Re-reads the wall directly from the repository and applies it to this
  /// cubit's state. [watchWall]'s stream doesn't re-emit for local-session
  /// changes (see [reshapeGrid]/[capturePhoto]), so a screen whose grid was
  /// reshaped by a *different* [CaptureSessionCubit] instance further up the
  /// navigation stack (each screen creates its own, per this cubit's class
  /// doc) needs to pull the fresh grid explicitly when it becomes visible
  /// again rather than waiting for an event that will never arrive.
  void refresh() => _onWallChanged(_repository.getWall(_floorId, _wallId));

  void _onWallChanged(WallEntity? wall) {
    if (wall == null) {
      emit(const CaptureSessionNotFound());
      return;
    }
    final current = state;
    emit(
      current is CaptureSessionLoaded
          ? current.copyWith(wall: wall)
          : CaptureSessionLoaded(
              wall: wall,
              activeCellId: _pendingActiveCellId,
              cellQuality: _repository.getCellQuality(_floorId, _wallId),
            ),
    );
  }

  void incRows() => _adjustCustom(rowDelta: 1);

  void decRows() => _adjustCustom(rowDelta: -1);

  void incCols() => _adjustCustom(colDelta: 1);

  void decCols() => _adjustCustom(colDelta: -1);

  void _adjustCustom({int rowDelta = 0, int colDelta = 0}) {
    final current = state;
    if (current is! CaptureSessionLoaded) return;
    final nextRows = _clampDimension(current.customRows + rowDelta);
    final nextCols = _clampDimension(current.customCols + colDelta);
    if (nextRows * nextCols > _maxGridCells) return;
    emit(current.copyWith(customRows: nextRows, customCols: nextCols));
  }

  int _clampDimension(int value) {
    if (value < 1) return 1;
    if (value > _maxGridDimension) return _maxGridDimension;
    return value;
  }

  Future<StorageCheckResult> checkStorageForNewSession(int cellCount) =>
      _repository.checkStorageForNewSession(cellCount);

  void pickPreset(int rows, int cols) =>
      _repository.createGrid(_floorId, _wallId, rows, cols);

  void useCustomGrid() {
    final current = state;
    if (current is! CaptureSessionLoaded) return;
    _repository.createGrid(
      _floorId,
      _wallId,
      current.customRows,
      current.customCols,
    );
  }

  /// Resizes the wall's already-initialized grid. Applies the resulting
  /// wall to this cubit's own state directly — same reason [takePhoto]
  /// does: [watchWall]'s stream never re-emits for a session-local change.
  GridReshapeResult reshapeGrid(int rows, int cols) {
    final outcome = _repository.reshapeGrid(_floorId, _wallId, rows, cols);
    if (outcome.wall != null) _onWallChanged(outcome.wall);
    return outcome.result;
  }

  void openCell(int index) {
    _pendingActiveCellId = index;
    final current = state;
    if (current is CaptureSessionLoaded) {
      emit(current.copyWith(activeCellId: index));
    }
  }

  /// Saves [capturedFile] under the grid-cell naming convention, then
  /// records it against the active cell. No-ops if no cell is open (the
  /// shutter should be unreachable in that state, but this guards against a
  /// stray tap during a screen transition).
  Future<void> takePhoto(XFile capturedFile) async {
    final current = state;
    if (current is! CaptureSessionLoaded) return;
    final cellId = current.activeCellId;
    final grid = current.grid;
    if (cellId == null || grid == null) return;

    final row = cellId ~/ grid.cols + 1;
    final col = cellId % grid.cols + 1;
    final shotNumber = _nextShotNumber(grid.cells[cellId].shotPaths);

    final saved = await _localDataSource.saveShot(
      wallId: _wallId,
      row: row,
      col: col,
      shotNumber: shotNumber,
      capturedFile: capturedFile,
    );
    final updatedWall = _repository.capturePhoto(
      _floorId,
      _wallId,
      cellId,
      saved.path,
      sha256: saved.sha256,
      shot: shotNumber,
    );
    // watchWall()'s stream only re-emits on changes SiteRepository itself
    // watches (site/wall-status), which a capture never touches — apply the
    // new shot to this cubit's own state directly rather than waiting for an
    // event that will never arrive.
    if (updatedWall != null) {
      _onWallChanged(updatedWall);
      unawaited(_analyzeCellQuality(cellId));
    }
  }

  Future<void> deletePhoto(int cellId, String filePath) async {
    final current = state;
    final grid = current is CaptureSessionLoaded ? current.grid : null;
    if (grid == null ||
        cellId < 0 ||
        cellId >= grid.cells.length ||
        !grid.cells[cellId].shotPaths.contains(filePath)) {
      return;
    }

    final updatedWall = await _repository.deletePhoto(
      _floorId,
      _wallId,
      cellId,
      filePath,
    );
    // A retake can land back on this exact path (_nextShotNumber reuses the
    // deleted shot's number once it's gone) — evict it so Image.file, which
    // caches decoded bytes by path only, can't keep showing the file this
    // path used to point to.
    imageCache.evict(FileImage(File(filePath)));
    if (updatedWall != null) {
      _onWallChanged(updatedWall);
      // The remaining "first" shot (if any) may be a different file than
      // what was last scored — rescore so the badge never describes a
      // photo that's no longer the one on screen. A cell that's now empty
      // safely no-ops inside _analyzeCellQuality; its stale quality record
      // is simply never read once GridCellTile stops seeing shotPaths.
      unawaited(_analyzeCellQuality(cellId));
    }
  }

  /// Scores [cellIndex], then rescores every already-captured grid-adjacent
  /// neighbour exactly once (spec: "as soon as both this cell and at least
  /// one grid-adjacent cell have a captured photo") — [_scoreCell] itself
  /// never recurses into its own neighbours, which is what keeps this to
  /// one level: two grid-adjacent cells that both already have a photo
  /// would otherwise call back into each other forever (neither's
  /// [CaptureSessionLoaded.analyzingCellIds] guard is still set by the time
  /// the other's rescore loop runs, since each clears its own entry right
  /// after emitting its result).
  ///
  /// Persists every result from this wave (self plus up to 4 neighbours) in
  /// one [GridCaptureRepository.recordCellQualityBatch] call rather than one
  /// full-record Hive write per cell — up to a 5x cut in how many times a
  /// single shot re-serializes the whole (ever-growing) session record.
  Future<void> _analyzeCellQuality(int cellIndex) async {
    final results = <int, CellQualityResult>{};

    final selfResult = await _scoreCell(cellIndex);
    if (selfResult != null) results[cellIndex] = selfResult;

    final started = state;
    if (started is CaptureSessionLoaded) {
      final grid = started.grid;
      if (grid != null && cellIndex >= 0 && cellIndex < grid.cells.length) {
        final row = cellIndex ~/ grid.cols;
        final col = cellIndex % grid.cols;
        final neighbourIndices = [
          if (col > 0) cellIndex - 1,
          if (col < grid.cols - 1) cellIndex + 1,
          if (row > 0) cellIndex - grid.cols,
          if (row < grid.rows - 1) cellIndex + grid.cols,
        ];
        for (final neighbourIndex in neighbourIndices) {
          if (grid.cells[neighbourIndex].shotPaths.isNotEmpty) {
            final neighbourResult = await _scoreCell(neighbourIndex);
            if (neighbourResult != null) results[neighbourIndex] = neighbourResult;
          }
        }
      }
    }

    if (results.isNotEmpty) {
      _repository.recordCellQualityBatch(_floorId, _wallId, results);
    }
  }

  /// Runs Tier 1 (always) and Tier 2/3 (against every grid-adjacent cell
  /// that already has a photo) for [cellIndex]'s shots, emits the result,
  /// and returns it for [_analyzeCellQuality] to persist — every shot taken
  /// for the cell, not just the first, so a strong retake wins over a weak
  /// initial attempt. Returns null (a no-op) if the cell has no photo, an
  /// analysis for it is already in flight, or analysis fails. Never
  /// rescores its own neighbours — see [_analyzeCellQuality], the only
  /// caller that should trigger that.
  Future<CellQualityResult?> _scoreCell(int cellIndex) async {
    final started = state;
    if (started is! CaptureSessionLoaded) return null;
    final grid = started.grid;
    if (grid == null || cellIndex < 0 || cellIndex >= grid.cells.length) return null;
    if (started.analyzingCellIds.contains(cellIndex)) return null;

    final shotPaths = grid.cells[cellIndex].shotPaths;
    if (shotPaths.isEmpty) {
      // The cell's last photo was just deleted — this cubit's in-memory
      // cellQuality map isn't touched by _onWallChanged (it only carries
      // `wall` forward), so without this the stale result (and its
      // imagePath, pointing at a now-deleted file) would keep describing
      // this cell until a future shot happens to trigger a fresh analysis —
      // and if that shot's number reuses the deleted best shot's number,
      // representativeShotPath would match it by path and show the old
      // score against the new photo.
      if (started.cellQuality.containsKey(cellIndex)) {
        emit(
          started.copyWith(
            cellQuality: {...started.cellQuality}..remove(cellIndex),
          ),
        );
      }
      return null;
    }

    emit(started.copyWith(analyzingCellIds: {...started.analyzingCellIds, cellIndex}));

    final row = cellIndex ~/ grid.cols;
    final col = cellIndex % grid.cols;
    final neighbourCells = <NeighbourDirection, int>{
      if (col > 0) NeighbourDirection.left: cellIndex - 1,
      if (col < grid.cols - 1) NeighbourDirection.right: cellIndex + 1,
      if (row > 0) NeighbourDirection.top: cellIndex - grid.cols,
      if (row < grid.rows - 1) NeighbourDirection.bottom: cellIndex + grid.cols,
    };
    final capturedNeighbours = [
      for (final entry in neighbourCells.entries)
        if (grid.cells[entry.value].shotPaths.isNotEmpty)
          NeighbourImageInput(
            direction: entry.key,
            cellIndex: entry.value,
            imagePath: representativeShotPath(
              grid.cells[entry.value].shotPaths,
              started.cellQuality[entry.value],
            )!,
          ),
    ];

    try {
      final result = analyzeCellQuality(
        CellQualityRequest(
          cellIndex: cellIndex,
          imagePaths: shotPaths,
          relevantEdges: neighbourCells.keys.map((d) => d.edge).toSet(),
          neighbours: capturedNeighbours,
        ),
      );
      // analyzeCellQuality() never sets `overridden` (it has no notion of a
      // human decision) - read it from the repository rather than trusting
      // the cubit's own in-memory map, which would still be stale right
      // after this exact cell's photo was just replaced (capturePhoto
      // already reset the persisted flag by then; the in-memory map hasn't).
      // This doesn't need [result] to already be persisted first — the flag
      // lives independently of the quality record itself.
      final overridden = _repository.getCellQualityOverridden(_floorId, _wallId, cellIndex);
      final merged = result.withOverridden(overridden);
      final afterAnalysis = state;
      if (afterAnalysis is CaptureSessionLoaded) {
        emit(
          afterAnalysis.copyWith(
            cellQuality: {...afterAnalysis.cellQuality, cellIndex: merged},
            analyzingCellIds: {...afterAnalysis.analyzingCellIds}..remove(cellIndex),
          ),
        );
      }
      return merged;
    } catch (error) {
      debugPrint('CaptureSessionCubit: quality analysis failed for cell $cellIndex: $error');
      final afterFailure = state;
      if (afterFailure is CaptureSessionLoaded) {
        emit(
          afterFailure.copyWith(
            analyzingCellIds: {...afterFailure.analyzingCellIds}..remove(cellIndex),
          ),
        );
      }
      return null;
    }
  }

  /// Toggles the operator's "keep this shot anyway" decision for a
  /// red/orange cell. A no-op if that cell has no quality result yet (the
  /// badge that hosts this control isn't shown until one exists).
  void toggleQualityOverride(int cellIndex) {
    final current = state;
    if (current is! CaptureSessionLoaded) return;
    final existing = current.cellQuality[cellIndex];
    if (existing == null) return;

    final updated = existing.withOverridden(!existing.overridden);
    _repository.setCellQualityOverride(_floorId, _wallId, cellIndex, updated.overridden);
    emit(current.copyWith(cellQuality: {...current.cellQuality, cellIndex: updated}));
  }

  int _nextShotNumber(List<String> shotPaths) {
    final shotPattern = RegExp(r'_S(\d+)\.[^.]+$');
    var highestShot = shotPaths.length;
    for (final path in shotPaths) {
      final parsed = int.tryParse(shotPattern.firstMatch(path)?.group(1) ?? '');
      if (parsed != null && parsed > highestShot) highestShot = parsed;
    }
    return highestShot + 1;
  }

  void saveFull() => _repository.saveFull(_floorId, _wallId);

  void savePartial() => _repository.savePartial(_floorId, _wallId);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
