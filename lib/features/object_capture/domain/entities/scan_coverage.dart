import 'package:equatable/equatable.dart';

import 'scan_plan.dart';

/// An arc round the object the server found no photograph in, in degrees
/// counted from the scan's first photograph.
class CoverageGap extends Equatable {
  const CoverageGap({required this.fromDegrees, required this.toDegrees});

  final double fromDegrees;
  final double toDegrees;

  bool contains(double azimuth) {
    final width = ScanPlan.normalise(toDegrees - fromDegrees);
    final span = width == 0 ? 360.0 : width;
    return ScanPlan.normalise(azimuth - fromDegrees) < span;
  }

  @override
  List<Object?> get props => [fromDegrees, toDegrees];
}

/// Which of the plan's photographs have been taken.
class ScanCoverage extends Equatable {
  const ScanCoverage([this.captured = const {}]);

  /// How much further the operator is sent on round the object rather than
  /// back for a slice they have passed.
  static const double _keepGoingDegrees = 30;

  final Set<ScanCell> captured;

  int get capturedCount => captured.length;

  bool isCaptured(ScanCell cell) => captured.contains(cell);

  ScanCoverage withCaptured(ScanCell cell) => ScanCoverage({...captured, cell});

  int capturedIn(int ring) =>
      captured.where((cell) => cell.ring == ring).length;

  bool isRingComplete(int ring) =>
      capturedIn(ring) == ScanPlan.rings[ring].sectors;

  /// The ring being shot: the first with a photograph still to take. Null
  /// once every ring is done.
  int? get activeRing {
    for (var ring = 0; ring < ScanPlan.rings.length; ring++) {
      if (!isRingComplete(ring)) return ring;
    }
    return null;
  }

  /// Which way round the object the operator should go for the next
  /// photograph still to take in [ring]: positive is to their right, and the
  /// size is how far. Null when the ring is complete.
  ///
  /// An operator walks round one way, so the next slice ahead of them wins
  /// over a nearer one just behind: turning back is only asked for when it
  /// saves a real walk.
  double? turnToNextMissing(int ring, double azimuth) {
    double? ahead;
    double? behind;
    for (var sector = 0; sector < ScanPlan.rings[ring].sectors; sector++) {
      final cell = ScanCell(ring, sector);
      if (isCaptured(cell)) continue;
      final toRight = ScanPlan.normalise(ScanPlan.centreOf(cell) - azimuth);
      final toLeft = 360 - toRight;
      if (ahead == null || toRight < ahead) ahead = toRight;
      if (behind == null || toLeft < behind) behind = toLeft;
    }
    if (ahead == null || behind == null) return null;
    return ahead <= behind + _keepGoingDegrees ? ahead : -behind;
  }

  /// The same coverage with every photograph inside [gaps] to be taken
  /// again: the server could not use what was shot there.
  ScanCoverage reopened(List<CoverageGap> gaps) {
    return ScanCoverage({
      for (final cell in captured)
        if (!gaps.any((gap) => gap.contains(ScanPlan.centreOf(cell)))) cell,
    });
  }

  @override
  List<Object?> get props => [captured];
}
