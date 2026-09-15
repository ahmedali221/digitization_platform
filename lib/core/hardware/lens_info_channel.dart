import 'package:flutter/services.dart';

/// Which of the device's back-facing `CameraDescription`s (by `.name`, as
/// returned by `availableCameras()`) is the true primary lens and, if the
/// device has one, which is the ultra-wide.
class BackLensRoles {
  const BackLensRoles({
    required this.primaryName,
    this.ultraWideName,
    this.ultraWideZoomRatio,
  });

  final String primaryName;
  final String? ultraWideName;

  /// The ultra-wide lens's zoom multiplier relative to the primary lens
  /// (e.g. `0.5`). Null whenever [ultraWideName] is null.
  final double? ultraWideZoomRatio;
}

/// Resolves back-lens roles the way the platform camera stack actually
/// reports them, rather than guessing from `CameraDescription` ordering.
///
/// `camera_android_camerax` names every camera "Camera 0", "Camera 1"... in
/// whatever order CameraX happens to enumerate them — not by Camera2 ID —
/// so "the second back camera is the ultra-wide" silently breaks on devices
/// where CameraX orders lenses differently (this is also what let the old
/// `int.tryParse(camera.name)` sort silently no-op: `"Camera 0"` isn't a
/// parseable int, so every comparison collapsed to `0 vs 0` and the "sort"
/// never actually reordered anything). That combination is what caused 1x to
/// sometimes render as if it were 0.5x. This channel asks each platform
/// directly: Android by comparing every back lens's 35mm-equivalent focal
/// length against the lowest-Camera2-ID (primary) lens; iOS by asking
/// AVFoundation for `.builtInWideAngleCamera`/`.builtInUltraWideCamera`
/// directly.
class LensInfoChannel {
  LensInfoChannel._();

  static const _channel = MethodChannel('nilelens/lens_info');

  /// Returns null if the platform can't confirm a primary back lens at all
  /// (no native wiring, or the platform call failed) — callers should fall
  /// back to treating the first back `CameraDescription` as primary and
  /// hiding the ultra-wide preset.
  static Future<BackLensRoles?> getBackLensRoles() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getBackLensRoles',
      );
      if (result == null) return null;
      final primaryName = result['primaryName'] as String?;
      if (primaryName == null) return null;
      return BackLensRoles(
        primaryName: primaryName,
        ultraWideName: result['ultraWideName'] as String?,
        ultraWideZoomRatio: (result['ultraWideZoomRatio'] as num?)
            ?.toDouble(),
      );
    } catch (_) {
      // Best-effort — a platform without this native wiring (or any
      // platform-channel failure) must never block the camera screen; the
      // caller just falls back to its own heuristic.
      return null;
    }
  }
}
