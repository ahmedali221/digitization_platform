import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../grid_capture/domain/entities/capture_quality.dart';
import '../../../grid_capture/domain/services/capture_quality_config.dart';
import '../../../grid_capture/domain/services/cell_quality_analyzer.dart';

/// Two grid neighbours that don't look as if they'll join.
typedef WeakLink = ({int from, int to});

class FollowUpGridState {
  const FollowUpGridState({
    this.rows = 1,
    this.cols = 2,
    this.photos = const {},
    this.activeCell = 0,
    this.lastTakenCell,
    this.quality = const {},
    this.links = const {},
    this.sending = false,
    this.sendError,
  });

  final int rows;
  final int cols;

  /// One photograph per cell, keyed by cell, row by row.
  final Map<int, String> photos;
  final int activeCell;

  /// Where the latest photograph went, which may since have been deleted. The
  /// active cell has usually moved on from it by then.
  final int? lastTakenCell;
  final Map<int, CellQualityResult> quality;

  /// How each scored pair of neighbours matched: see [_pair].
  final Map<int, NeighbourMatchMetrics> links;

  /// Being handed over, during which the photographs must stay where they are.
  final bool sending;

  /// Why the last attempt to send failed, until the next attempt.
  final Object? sendError;

  int get cellCount => rows * cols;
  bool get isComplete => photos.length == cellCount;

  /// The cell whose photograph the camera offers to open: the one selected, or
  /// failing that the latest taken. Null when neither has a photograph.
  int? get reviewableCell {
    if (photos.containsKey(activeCell)) return activeCell;
    return photos.containsKey(lastTakenCell) ? lastTakenCell : null;
  }

  /// The score of two neighbours, or null when they haven't both been scored.
  NeighbourMatchMetrics? link(int a, int b) => links[_pair(a, b)];

  /// Pairs of photographed neighbours the analyzer gives little hope of joining.
  /// A pair not scored yet isn't counted: it's the score that's the warning.
  List<WeakLink> get weakLinks {
    const config = CaptureQualityConfig();
    return [
      for (final entry in links.entries)
        if (qualityTierForScore(
              entry.value.neighbourScore,
              redMaxScore: config.redMaxScore,
              orangeMaxScore: config.orangeMaxScore,
              yellowMaxScore: config.yellowMaxScore,
            ) ==
            QualityTier.red)
          _unpair(entry.key, cols),
    ];
  }

  FollowUpGridState copyWith({
    int? rows,
    int? cols,
    Map<int, String>? photos,
    int? activeCell,
    int? lastTakenCell,
    Map<int, CellQualityResult>? quality,
    Map<int, NeighbourMatchMetrics>? links,
    bool? sending,
    Object? sendError,
    bool clearSendError = false,
  }) => FollowUpGridState(
    rows: rows ?? this.rows,
    cols: cols ?? this.cols,
    photos: photos ?? this.photos,
    activeCell: activeCell ?? this.activeCell,
    lastTakenCell: lastTakenCell ?? this.lastTakenCell,
    quality: quality ?? this.quality,
    links: links ?? this.links,
    sending: sending ?? this.sending,
    sendError: clearSendError ? null : sendError ?? this.sendError,
  );
}

/// A pair as a single key: the earlier cell, and which way the other one is.
int _pair(int a, int b) {
  final from = a < b ? a : b;
  final to = a < b ? b : a;
  return from * 2 + (to == from + 1 ? 0 : 1);
}

WeakLink _unpair(int key, int cols) {
  final from = key ~/ 2;
  return (from: from, to: key.isEven ? from + 1 : from + cols);
}

/// A grid of photographs of one annotation, which the dashboard will stitch.
///
/// Apart from CaptureSessionCubit, whose every step is a wall's: it saves to the
/// wall's grid and can queue the wall's sync, and this must never touch a wall.
/// One photograph per cell, and a retake replaces it.
class FollowUpGridCubit extends Cubit<FollowUpGridState> {
  FollowUpGridCubit(this._analyzer) : super(const FollowUpGridState());

  final CellQualityAnalyzer _analyzer;

  /// The dashboard's limits: see its RecaptureGridController.
  static const int maxSide = 6;
  static const int maxCells = 24;
  static const int minCells = 2;

  bool _fits(int rows, int cols) {
    final cells = rows * cols;
    return rows >= 1 && cols >= 1 && rows <= maxSide && cols <= maxSide && cells >= minCells && cells <= maxCells;
  }

  /// Its shape is only for choosing before the first photograph.
  void resize({int? rows, int? cols}) {
    if (state.photos.isNotEmpty) return;
    final nextRows = rows ?? state.rows;
    final nextCols = cols ?? state.cols;
    // Back to the first cell: the active one may be outside a smaller grid,
    // once every photograph has been deleted from a bigger one.
    if (_fits(nextRows, nextCols)) emit(state.copyWith(rows: nextRows, cols: nextCols, activeCell: 0));
  }

  void select(int cell) => emit(state.copyWith(activeCell: cell));

  /// Keeps [path] as the active cell's photograph, and moves on to the next cell
  /// with none. Its score comes later, and the camera doesn't wait for it.
  Future<void> addPhoto(String path) async {
    final cell = state.activeCell;
    final replaced = state.photos[cell];
    final photos = {...state.photos, cell: path};

    emit(
      state.copyWith(
        photos: photos,
        activeCell: _nextEmpty(cell, photos),
        lastTakenCell: cell,
        quality: {...state.quality}..remove(cell),
        links: _withoutLinksOf(cell),
      ),
    );

    if (replaced != null) await _deleteFile(replaced);

    await _score(cell, path);
  }

  /// Deletes [cell]'s photograph and selects the cell, so the next one taken
  /// fills the gap. A score still running for it is dropped when it arrives.
  Future<void> removePhoto(int cell) async {
    final removed = state.photos[cell];
    if (removed == null) return;

    emit(
      state.copyWith(
        photos: {...state.photos}..remove(cell),
        activeCell: cell,
        quality: {...state.quality}..remove(cell),
        links: _withoutLinksOf(cell),
      ),
    );

    await _deleteFile(removed);
  }

  /// Hands the grid to [queue], and returns whether this call got it there: false
  /// if it was already on its way, or if [queue] threw. Then [FollowUpGridState.sendError]
  /// says why, and every photograph is still here to try again.
  Future<bool> send(Future<void> Function(FollowUpGridState grid) queue) async {
    if (state.sending) return false;
    emit(state.copyWith(sending: true, clearSendError: true));
    try {
      await queue(state);
      if (!isClosed) emit(state.copyWith(sending: false));
      return true;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(sending: false, sendError: error));
      return false;
    }
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  int _nextEmpty(int from, Map<int, String> photos) {
    for (var step = 1; step <= state.cellCount; step++) {
      final candidate = (from + step) % state.cellCount;
      if (!photos.containsKey(candidate)) return candidate;
    }
    return from;
  }

  Map<int, NeighbourMatchMetrics> _withoutLinksOf(int cell) {
    final cols = state.cols;
    final links = {...state.links};
    links.removeWhere((key, _) {
      final pair = _unpair(key, cols);
      return pair.from == cell || pair.to == cell;
    });
    return links;
  }

  Map<NeighbourDirection, int> _neighboursOf(int cell) {
    final cols = state.cols;
    final col = cell % cols;
    return {
      if (col > 0) NeighbourDirection.left: cell - 1,
      if (col < cols - 1) NeighbourDirection.right: cell + 1,
      if (cell - cols >= 0) NeighbourDirection.top: cell - cols,
      if (cell + cols < state.cellCount) NeighbourDirection.bottom: cell + cols,
    };
  }

  /// Compares a photograph with its neighbours so far. Each pair is scored from
  /// whichever side was taken last, so one analysis per photograph covers them all.
  Future<void> _score(int cell, String path) async {
    final neighbours = _neighboursOf(cell);
    try {
      final result = await _analyzer.analyze(
        CellQualityRequest(
          cellIndex: cell,
          imagePaths: [path],
          relevantEdges: neighbours.keys.map((direction) => direction.edge).toSet(),
          neighbours: [
            for (final entry in neighbours.entries)
              if (state.photos[entry.value] != null)
                NeighbourImageInput(
                  direction: entry.key,
                  cellIndex: entry.value,
                  imagePath: state.photos[entry.value]!,
                ),
          ],
        ),
      );

      // Retaken or closed while that ran: the answer is about a photograph that's gone.
      if (isClosed || state.photos[cell] != path) return;

      emit(
        state.copyWith(
          quality: {...state.quality, cell: result},
          links: {
            ...state.links,
            for (final link in result.neighbours)
              // Unless that neighbour was retaken meanwhile, whose own score will say.
              if (state.photos[link.neighbourCellIndex] != null)
                _pair(cell, link.neighbourCellIndex): link,
          },
        ),
      );
    } catch (error) {
      // Only ever a warning: the dashboard is what decides whether they join.
      debugPrint('FollowUpGridCubit: could not score cell $cell: $error');
    }
  }
}
