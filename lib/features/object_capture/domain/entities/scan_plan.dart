import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// One pass round the object at one height: how high the camera looks from,
/// and how many photographs the pass is cut into.
class ScanRing extends Equatable {
  const ScanRing({
    required this.name,
    required this.instruction,
    required this.sectors,
    required this.minElevation,
  });

  final String name;

  /// What to tell an operator who is not holding the phone for this ring.
  final String instruction;

  /// Photographs in a full turn. Fewer from above, where each one sees more.
  final int sectors;

  /// Degrees the camera looks down at the object from, at the least. A ring
  /// reaches up to where the next one begins.
  final double minElevation;

  double get sectorDegrees => 360 / sectors;

  @override
  List<Object?> get props => [name, sectors, minElevation];
}

/// One photograph the plan asks for: a slice of one ring.
class ScanCell extends Equatable {
  const ScanCell(this.ring, this.sector);

  final int ring;
  final int sector;

  @override
  List<Object?> get props => [ring, sector];
}

/// The photographs a scan is made of. The app, not the operator, decides how
/// many: neighbouring photographs must share about two thirds of what they
/// show for a reconstruction to join them, which a 15 degree step gives at
/// arm's length from an object.
class ScanPlan {
  const ScanPlan._();

  static const rings = [
    ScanRing(
      name: 'Level',
      instruction: 'Hold the phone level with the middle of the object.',
      sectors: 24,
      minElevation: -90,
    ),
    ScanRing(
      name: 'From above',
      instruction: 'Raise the phone and point it down at the object.',
      sectors: 16,
      minElevation: 25,
    ),
  ];

  /// Fewer photographs than this cannot be reconstructed, and the server
  /// refuses the scan (`min_usable_photos` in its quality settings).
  static const minimumShots = 12;

  static int get totalCells =>
      rings.fold(0, (count, ring) => count + ring.sectors);

  /// The ring a camera looking down from [elevation] degrees is shooting.
  static int ringAt(double elevation) {
    for (var index = rings.length - 1; index > 0; index--) {
      if (elevation >= rings[index].minElevation) return index;
    }
    return 0;
  }

  /// The slice of [ring] that [azimuth] degrees round the object falls in.
  static ScanCell cellAt(int ring, double azimuth) {
    final sector = (normalise(azimuth) / rings[ring].sectorDegrees).floor();
    return ScanCell(ring, sector % rings[ring].sectors);
  }

  /// Degrees round the object at the middle of [cell].
  static double centreOf(ScanCell cell) =>
      (cell.sector + 0.5) * rings[cell.ring].sectorDegrees;

  static double normalise(double degrees) => degrees % 360;

  /// The shortest way from [from] to [to] degrees: positive is anticlockwise
  /// seen from above, which for someone facing the object is to their right.
  static double shortestTurn(double from, double to) {
    final turn = normalise(to - from);
    return turn > 180 ? turn - 360 : turn;
  }
}

/// Where the camera is looking from, relative to the object: degrees round
/// it, and degrees above its horizon.
class CameraDirection extends Equatable {
  const CameraDirection({required this.azimuth, required this.elevation});

  /// From the camera's viewing direction as a unit vector with z up. Round
  /// the object the camera stands opposite to where it looks, but only
  /// differences in azimuth are ever used, so the constant half turn is
  /// left out.
  factory CameraDirection.fromForward(double x, double y, double z) {
    return CameraDirection(
      azimuth: ScanPlan.normalise(math.atan2(y, x) * _degreesPerRadian),
      // Looking down is a negative z: the camera is above what it looks at.
      elevation: math.asin((-z).clamp(-1.0, 1.0)) * _degreesPerRadian,
    );
  }

  static const _degreesPerRadian = 180 / math.pi;

  final double azimuth;
  final double elevation;

  @override
  List<Object?> get props => [azimuth, elevation];
}
