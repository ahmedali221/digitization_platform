import '../entities/scan_coverage.dart';
import '../entities/scan_plan.dart';

/// What the scan screen tells the operator to do next.
enum ScanGuidance {
  /// A photograph is due here and the phone is still: take it.
  shoot,
  holdStill,
  slowDown,
  moveRight,
  moveLeft,

  /// The phone is not at the height of the ring being shot.
  wrongHeight,
  finished,
}

/// Decides, many times a second, whether to take a photograph: the operator
/// only moves the phone round the object.
///
/// A photograph is taken once per slice of the plan, the first moment the
/// phone is in that slice and still. Stillness is judged by how fast the
/// phone turns, which is what smears a handheld photograph.
class AutoShutter {
  const AutoShutter._();

  /// Radians per second. Below [stillBelow] a photograph comes out sharp in
  /// room light; above [tooFastAbove] the operator would pass a slice before
  /// the phone could settle in it.
  static const double stillBelow = 0.12;
  static const double tooFastAbove = 0.9;

  /// How long the phone must have been still before the photograph is
  /// taken. The first real scan shot the instant the phone stopped, and a
  /// third of its photographs were soft: the hand was still settling and
  /// the lens still focusing.
  static const Duration settleTime = Duration(milliseconds: 450);

  static ScanGuidance guide({
    required ScanCoverage coverage,
    required CameraDirection direction,
    required double turningRate,
  }) {
    final ring = coverage.activeRing;
    if (ring == null) return ScanGuidance.finished;
    if (ScanPlan.ringAt(direction.elevation) != ring) {
      return ScanGuidance.wrongHeight;
    }
    if (turningRate > tooFastAbove) return ScanGuidance.slowDown;

    final cell = ScanPlan.cellAt(ring, direction.azimuth);
    if (!coverage.isCaptured(cell)) {
      return turningRate < stillBelow
          ? ScanGuidance.shoot
          : ScanGuidance.holdStill;
    }

    final turn = coverage.turnToNextMissing(ring, direction.azimuth)!;
    return turn > 0 ? ScanGuidance.moveRight : ScanGuidance.moveLeft;
  }
}
