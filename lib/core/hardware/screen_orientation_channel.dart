import 'package:flutter/services.dart';

/// Lets a capture screen turn with the phone even when the phone's auto-rotate
/// is off, so an operator who turns it sideways for a wide wall gets a
/// landscape screen to match.
///
/// Android only (`MainActivity`); on iOS the call is a no-op and the screen
/// turns as the system allows, which `Info.plist` already does for landscape.
class ScreenOrientationChannel {
  ScreenOrientationChannel._();

  static const _channel = MethodChannel('nilelens/screen_orientation');

  /// Turns the screen with the device's sensor. Call when a capture screen opens.
  static Future<void> followSensor() => _invoke('followSensor');

  /// Gives orientation back to the system setting. Call when the capture
  /// screen closes, or every other screen would keep ignoring the rotation lock.
  static Future<void> release() => _invoke('release');

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Best-effort: without the native side the screen simply follows the
      // system setting, which must never stop the camera from opening.
    }
  }
}
