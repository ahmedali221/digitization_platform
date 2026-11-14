import 'package:flutter/services.dart';

/// Where the back camera points, as a unit vector in a frame whose z axis
/// points up, and how fast the phone is turning in radians per second.
class DeviceMotionSample {
  const DeviceMotionSample({
    required this.forwardX,
    required this.forwardY,
    required this.forwardZ,
    required this.turningRate,
  });

  final double forwardX;
  final double forwardY;
  final double forwardZ;
  final double turningRate;
}

/// The phone's fused motion sensors: `DeviceMotionStreamHandler` on Android
/// (game rotation vector and gyroscope) and on iPhone (Core Motion). The
/// compass is left out on both, so steel nearby cannot swing the heading;
/// the horizontal zero is therefore arbitrary and only differences mean
/// anything.
class DeviceMotionChannel {
  DeviceMotionChannel._();

  static const _events = EventChannel('nilelens/device_motion');

  /// Errors with a [PlatformException] on a phone without the sensors.
  static Stream<DeviceMotionSample> samples() {
    return _events.receiveBroadcastStream().map((event) {
      final values = (event as List<Object?>).cast<num>();
      return DeviceMotionSample(
        forwardX: values[0].toDouble(),
        forwardY: values[1].toDouble(),
        forwardZ: values[2].toDouble(),
        turningRate: values[3].toDouble(),
      );
    });
  }
}
