import '../../../../core/hardware/device_motion_channel.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/services/camera_motion_source.dart';

/// [CameraMotionSource] read from the phone's own motion sensors.
class DeviceCameraMotionSource implements CameraMotionSource {
  const DeviceCameraMotionSource();

  @override
  Stream<CameraMotion> watch() {
    return DeviceMotionChannel.samples().map(
      (sample) => CameraMotion(
        direction: CameraDirection.fromForward(
          sample.forwardX,
          sample.forwardY,
          sample.forwardZ,
        ),
        turningRate: sample.turningRate,
      ),
    );
  }
}
