import 'package:equatable/equatable.dart';

import '../../theme/wall_status.dart';
import 'object_metadata.dart';
import 'object_type.dart';

/// One grid cell's captured shots, in capture order (`S1`, `S2`, ...).
/// `shotPaths` holds real local file paths — both the real camera repository
/// and any later on-device compositing need actual files, not just a count.
///
/// Capture Quality Indicator results are deliberately NOT part of this
/// entity: `WallEntity`/`GridState`/`GridCell` are shared across features
/// (map_navigation, site_backup, ...) via `SiteRepository`, while quality
/// scoring is grid_capture's own concern. See `CaptureSessionCubit` /
/// `GridCaptureRepository.getCellQuality`.
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

/// A wall, or any other record on a floor that is captured the same way: a
/// painting, a statue, a stela. The class keeps its name because the server
/// row it mirrors does, and every capture and sync path is keyed by its [id].
class WallEntity extends Equatable {
  const WallEntity({
    required this.id,
    required this.floorId,
    required this.name,
    required this.status,
    required this.lastCapture,
    this.notes = '',
    this.grid,
    this.roomLabel,
    this.hallId,
    this.objectType = ObjectType.wall,
    this.captureMode = CaptureMode.grid,
    this.metadata = ObjectMetadata.empty,
    this.intakeStatus = IntakeStatus.accepted,
    this.capturedSides = const {},
    this.serverId,
  });

  /// How this phone refers to the record: the server's wall id, or, for one
  /// created here, a `local_`-prefixed id that stays its id on this phone
  /// even after the server has given it a real one (see [serverId]).
  final String id;
  final String floorId;
  final String name;
  final String notes;
  final WallStatus status;
  final String lastCapture;
  final GridState? grid;

  /// The name of the chamber or hall this record is filed under. Rooms drawn
  /// on the map claim their walls by geometry first; this groups everything
  /// else (see `FloorWallsPage`'s `_roomFilters`).
  final String? roomLabel;

  /// The server's id for that chamber, when it has one.
  final String? hallId;

  final ObjectType objectType;

  /// Not always [ObjectType.captureMode]: a wall can be either, and the
  /// dashboard can convert a record from one to the other.
  final CaptureMode captureMode;
  final ObjectMetadata metadata;
  final IntakeStatus intakeStatus;

  /// The sides the server already holds a photograph of, as of the last
  /// downloaded package. This phone's own shots are not in here.
  final Set<ObjectSide> capturedSides;

  /// The server's wall id for a record created on this phone, once it has
  /// been sent. Null before that, and for records that came from a package.
  final String? serverId;

  /// Matches FLUTTER_MOBILE_PLAN.md §2/§4: the capture entry point is
  /// available at every status — label swaps, the action is never disabled.
  bool get hasGrid => grid != null;

  /// Created on this phone (`SiteRepository.addItem`).
  bool get isLocal => id.startsWith(localIdPrefix);

  /// Created on this phone and not yet known to the server.
  bool get isOnlyOnThisPhone => isLocal && serverId == null;

  bool get isAwaitingReview => intakeStatus == IntakeStatus.pending;

  static const localIdPrefix = 'local_';

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
      roomLabel: roomLabel,
      hallId: hallId,
      objectType: objectType,
      captureMode: captureMode,
      metadata: metadata,
      intakeStatus: intakeStatus,
      capturedSides: capturedSides,
      serverId: serverId,
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
    roomLabel,
    hallId,
    objectType,
    captureMode,
    metadata,
    intakeStatus,
    capturedSides,
    serverId,
  ];
}
