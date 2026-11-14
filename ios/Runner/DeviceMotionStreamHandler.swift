import CoreMotion
import Flutter

/// Streams where the back camera points and how fast the phone is turning, for Dart's
/// `DeviceMotionChannel`: the iPhone counterpart of Android's `DeviceMotionStreamHandler`,
/// sending the same `[x, y, z, rate]` events (viewing direction in a frame whose z axis points
/// up, turning rate in radians per second).
///
/// The reference frame leaves the compass out (`xArbitraryZVertical`), for the reason given on
/// the Android side: nearby steel must not swing the heading.
final class DeviceMotionStreamHandler: NSObject, FlutterStreamHandler {
  private static let updatesPerSecond = 30.0

  private let motionManager = CMMotionManager()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard motionManager.isDeviceMotionAvailable else {
      return FlutterError(
        code: "unavailable", message: "This phone has no motion sensors.", details: nil)
    }
    motionManager.deviceMotionUpdateInterval = 1.0 / Self.updatesPerSecond
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
      guard let motion = motion else { return }
      // The attitude matrix takes the reference frame to the phone's axes, so the phone's
      // axes seen from the reference frame are its rows. The back camera looks along the
      // phone's -z: minus the third row.
      let attitude = motion.attitude.rotationMatrix
      let rate = motion.rotationRate
      events([
        -attitude.m31,
        -attitude.m32,
        -attitude.m33,
        (rate.x * rate.x + rate.y * rate.y + rate.z * rate.z).squareRoot(),
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopDeviceMotionUpdates()
    return nil
  }
}
