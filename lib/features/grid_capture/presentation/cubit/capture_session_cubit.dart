import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import 'capture_session_state.dart';

/// Fixed rows x cols choices offered on the grid-init screen, in addition to
/// the custom stepper.
typedef GridPreset = ({int rows, int cols, String label});

const List<GridPreset> kGridPresets = [
  (rows: 2, cols: 2, label: '2 × 2'),
  (rows: 3, cols: 3, label: '3 × 3'),
  (rows: 4, cols: 3, label: '4 × 3'),
];

const _maxGridDimension = 10;
const _maxGridCells = 100;

/// Backs the grid-init, grid-capture, camera-capture, and coverage-review
/// screens — one linear capture session, so one cubit (rather than a cubit
/// per screen per CLAUDE.md's usual "one cubit per screen" default, which
/// would otherwise force each screen to re-derive the others' in-flight
/// state). Each screen provides its own instance and calls [init]; the
/// underlying [GridCaptureRepository] stream is the real source of truth for
/// wall/grid data, so a freshly-created instance always picks up whatever
/// the previous screen just wrote.
class CaptureSessionCubit extends Cubit<CaptureSessionState> {
  CaptureSessionCubit(this._repository, this._localDataSource)
    : super(const CaptureSessionLoading());

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
    if (updatedWall != null) _onWallChanged(updatedWall);
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
    if (updatedWall != null) _onWallChanged(updatedWall);
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

  void toggleExposureLock() {
    final current = state;
    if (current is CaptureSessionLoaded) {
      emit(current.copyWith(exposureLocked: !current.exposureLocked));
    }
  }

  void saveFull() => _repository.saveFull(_floorId, _wallId);

  void savePartial() => _repository.savePartial(_floorId, _wallId);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
