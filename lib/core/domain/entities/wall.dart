import 'package:equatable/equatable.dart';

import '../../theme/wall_status.dart';

/// One grid cell's captured shots, in capture order (`S1`, `S2`, ...).
/// `shotPaths` holds real local file paths — both the real camera repository
/// and any later on-device compositing need actual files, not just a count.
class GridCell extends Equatable {
  const GridCell({this.shotPaths = const []});

  final List<String> shotPaths;

  int get photoCount => shotPaths.length;
  bool get hasPhotos => shotPaths.isNotEmpty;

  GridCell withShotAdded(String path) =>
      GridCell(shotPaths: [...shotPaths, path]);

  @override
  List<Object?> get props => [shotPaths];
}

/// A wall's coverage grid. `cells` is row-major:
/// index = row * cols + col (matches FLUTTER_MOBILE_PLAN.md §3's manifest shape).
class GridState extends Equatable {
  const GridState({
    required this.rows,
    required this.cols,
    required this.cells,
  });

  final int rows;
  final int cols;
  final List<GridCell> cells;

  int get filledCount => cells.where((c) => c.hasPhotos).length;
  bool get isComplete => filledCount == cells.length;

  GridState withShotAdded(int index, String path) {
    final next = List<GridCell>.of(cells);
    next[index] = next[index].withShotAdded(path);
    return GridState(rows: rows, cols: cols, cells: next);
  }

  @override
  List<Object?> get props => [rows, cols, cells];
}

class WallEntity extends Equatable {
  const WallEntity({
    required this.id,
    required this.floorId,
    required this.name,
    required this.status,
    required this.lastCapture,
    this.notes = '',
    this.grid,
  });

  final String id;
  final String floorId;
  final String name;
  final String notes;
  final WallStatus status;
  final String lastCapture;
  final GridState? grid;

  /// Matches FLUTTER_MOBILE_PLAN.md §2/§4: the capture entry point is
  /// available at every status — label swaps, the action is never disabled.
  bool get hasGrid => grid != null;

  WallEntity copyWith({
    String? name,
    String? notes,
    WallStatus? status,
    String? lastCapture,
    GridState? grid,
    bool clearGrid = false,
  }) {
    return WallEntity(
      id: id,
      floorId: floorId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      lastCapture: lastCapture ?? this.lastCapture,
      grid: clearGrid ? null : (grid ?? this.grid),
    );
  }

  @override
  List<Object?> get props => [
    id,
    floorId,
    name,
    notes,
    status,
    lastCapture,
    grid,
  ];
}
