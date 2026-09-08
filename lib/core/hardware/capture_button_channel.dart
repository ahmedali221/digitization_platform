import 'package:flutter/services.dart';

/// Bridges a physical shutter press — the volume rocker, or any Bluetooth
/// remote/selfie-stick that pairs as one (the overwhelming majority just
/// emulate volume-up/down) — to the in-app capture shutter.
///
/// The native side (Android's `MainActivity`, iOS's `AppDelegate`) only
/// swallows the volume keys and reports presses here while [setEnabled(true)]
/// is armed; everywhere else in the app the volume buttons behave normally.
/// Armed only while [CameraCapturePage] is on screen — see its `initState`/
/// `dispose`.
class CaptureButtonChannel {
  CaptureButtonChannel._();

  static const _channel = MethodChannel('nilelens/capture_button');

  /// Registers [onPressed] for every future press and arms native-side
  /// interception. Call from the capture screen's `initState`.
  static void listen(void Function() onPressed) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'capturePressed') onPressed();
    });
    _setEnabled(true);
  }

  /// Disarms native-side interception and drops the handler. Call from the
  /// capture screen's `dispose` — leaving this armed would swallow the
  /// operator's volume buttons on every other screen.
  static void stop() {
    _channel.setMethodCallHandler(null);
    _setEnabled(false);
  }

  static Future<void> _setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEnabled', enabled);
    } catch (_) {
      // Best-effort — a platform without this native wiring (or any
      // platform-channel failure) must never block the camera screen itself,
      // it just means the volume buttons stay as plain volume buttons.
    }
  }
}
