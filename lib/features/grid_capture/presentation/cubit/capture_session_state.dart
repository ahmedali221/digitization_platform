import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/wall.dart';

/// States for the shared grid-init / grid-capture / camera / coverage-review
/// session cubit — the four feedback states required by DESIGN_SYSTEM.md §8
/// (loading/empty/error/content). "Empty" is the wall not resolving to any
/// entity in the repository (an unreachable case for the fake repository in
/// practice, but the real Hive-backed one can hit it on a stale deep link).
sealed class CaptureSessionState extends Equatable {
  const CaptureSessionState();

  @override
  List<Object?> get props => [];
}

class CaptureSessionLoading extends CaptureSessionState {
  const CaptureSessionLoading();
}

/// The requested zone/wall doesn't resolve to any entity in the repository.
class CaptureSessionNotFound extends CaptureSessionState {
  const CaptureSessionNotFound();
}

class CaptureSessionError extends CaptureSessionState {
  const CaptureSessionError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class CaptureSessionLoaded extends CaptureSessionState {
  const CaptureSessionLoaded({
    required this.wall,
    this.customRows = 2,
    this.customCols = 2,
    this.activeCellId,
    this.exposureLocked = false,
  });

  final WallEntity wall;

  /// Custom-grid stepper values on the grid-init screen only.
  final int customRows;
  final int customCols;

  /// The cell being photographed on the grid-capture/camera screens.
  final int? activeCellId;
  final bool exposureLocked;

  GridState? get grid => wall.grid;
  int get customCellCount => customRows * customCols;

  CaptureSessionLoaded copyWith({
    WallEntity? wall,
    int? customRows,
    int? customCols,
    int? activeCellId,
    bool? exposureLocked,
  }) {
    return CaptureSessionLoaded(
      wall: wall ?? this.wall,
      customRows: customRows ?? this.customRows,
      customCols: customCols ?? this.customCols,
      activeCellId: activeCellId ?? this.activeCellId,
      exposureLocked: exposureLocked ?? this.exposureLocked,
    );
  }

  @override
  List<Object?> get props => [
    wall,
    customRows,
    customCols,
    activeCellId,
    exposureLocked,
  ];
}
