import '../entities/scan_plan.dart';

/// Where the camera points and how fast the phone is turning, at one moment.
class CameraMotion {
  const CameraMotion({required this.direction, required this.turningRate});

  /// Azimuth here is absolute, from the sensors' own arbitrary zero.
  final CameraDirection direction;

  /// Radians per second.
  final double turningRate;
}

/// The phone's sense of where its camera points. Behind a contract so the
/// scan can be driven by recorded motion in tests.
abstract class CameraMotionSource {
  /// Errors when the phone has no motion sensors.
  Stream<CameraMotion> watch();
}
