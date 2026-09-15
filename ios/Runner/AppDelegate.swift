import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// Lets the camera screen treat the volume buttons — and any Bluetooth
/// shutter-remote/selfie-stick that pairs as one, which is how the
/// overwhelming majority of them work — as a physical shutter button instead
/// of the system volume control.
///
/// iOS has no public API to intercept the hardware volume keys directly, so
/// this uses the standard workaround: observe `AVAudioSession.outputVolume`
/// (a Bluetooth remote's "volume up/down" is exactly a real system-volume
/// change) and, on every change while armed, report a shutter press back to
/// Dart and silently snap the volume back to a fixed midpoint via a hidden
/// `MPVolumeView` — so the operator never sees the volume actually move, and
/// a press is always detectable in either direction (a slider pinned at 0 or
/// 1 can't register a further nudge that way).
///
/// Armed/disarmed by Dart's `CaptureButtonChannel` for the lifetime of
/// `CameraCapturePage`; the volume buttons behave normally everywhere else.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "nilelens/capture_button"
  private let lensInfoChannelName = "nilelens/lens_info"
  private var methodChannel: FlutterMethodChannel?

  private var captureButtonArmed = false
  private var restingVolume: Float = 0.5
  private var volumeBeforeArming: Float = 0.5
  private var suppressNextVolumeChange = false
  private var hiddenVolumeView: MPVolumeView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "setEnabled" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.setCaptureButtonArmed((call.arguments as? Bool) ?? false)
        result(nil)
      }
      methodChannel = channel

      let lensInfoChannel = FlutterMethodChannel(
        name: lensInfoChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      lensInfoChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "getBackLensRoles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.resolveBackLensRoles())
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Identifies the primary and (if present) ultra-wide back lenses the way
  /// `camera_avfoundation` itself names them — `CameraDescription.name` on
  /// iOS is the lens's `AVCaptureDevice.uniqueID` (see the plugin's
  /// `CameraPlugin.m availableCamerasWithCompletion:`).
  ///
  /// Note this project's `third_party/camera_avfoundation` fork prefers a
  /// single *virtual* multi-camera device (Triple/DualWide) for the back
  /// position on capable iPhones, whose one `AVCaptureDevice` already spans
  /// 0.5x-2x+ continuously — on those devices neither `.builtInWideAngleCamera`
  /// nor `.builtInUltraWideCamera` (both standalone *physical* lenses) will
  /// match the single `CameraDescription` `availableCameras()` actually
  /// returns, so both lookups below intentionally miss and Dart falls back
  /// to treating that one entry as primary with no separate ultra-wide to
  /// switch to (correct, since the virtual device's own zoom already covers
  /// it — see `_canReachUltraWide`'s fused-camera branch). This method still
  /// earns its keep on older/simpler back camera setups (e.g. plain wide +
  /// telephoto, no ultra-wide, no virtual device) where AVFoundation returns
  /// two independent physical lenses and picking the wrong one as "primary"
  /// is exactly the 1x-renders-as-something-else bug this exists to avoid.
  /// 0.5x is Apple's own fixed convention for the ultra-wide lens on every
  /// device that has one.
  private func resolveBackLensRoles() -> [String: Any]? {
    guard
      let primary = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .back)
    else {
      return nil
    }
    let ultraWide = AVCaptureDevice.default(
      .builtInUltraWideCamera, for: .video, position: .back)

    var response: [String: Any] = ["primaryName": primary.uniqueID]
    if let ultraWide = ultraWide {
      response["ultraWideName"] = ultraWide.uniqueID
      response["ultraWideZoomRatio"] = 0.5
    }
    return response
  }

  private func setCaptureButtonArmed(_ enabled: Bool) {
    guard enabled != captureButtonArmed else { return }
    captureButtonArmed = enabled

    let session = AVAudioSession.sharedInstance()
    if enabled {
      // `.ambient` + `.mixWithOthers` so this never interrupts audio another
      // app (or this one) might be playing — it only needs the session
      // active to read/observe `outputVolume`.
      try? session.setCategory(.ambient, options: [.mixWithOthers])
      try? session.setActive(true)
      installHiddenVolumeView()
      volumeBeforeArming = session.outputVolume
      snapVolume(to: 0.5)
      session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
    } else {
      session.removeObserver(self, forKeyPath: "outputVolume", context: nil)
      snapVolume(to: volumeBeforeArming)
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  /// A hidden `MPVolumeView`'s slider is the only public way to change the
  /// system volume in code — its mere presence in the view hierarchy (even
  /// off-screen) also happens to suppress the system's own volume HUD, which
  /// is exactly the behavior wanted here: the operator should see nothing
  /// change while capturing.
  private func installHiddenVolumeView() {
    guard hiddenVolumeView == nil, let window = window else { return }
    let view = MPVolumeView(frame: CGRect(x: -1_000, y: -1_000, width: 1, height: 1))
    window.addSubview(view)
    hiddenVolumeView = view
  }

  private func snapVolume(to value: Float) {
    guard let slider = hiddenVolumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
      return
    }
    restingVolume = value
    suppressNextVolumeChange = true
    slider.value = value
  }

  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard keyPath == "outputVolume", captureButtonArmed else { return }

    // AVAudioSession delivers this on a background thread; every UIKit call
    // below (the method channel included, by Flutter's own contract) must
    // happen on the main thread.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.suppressNextVolumeChange {
        self.suppressNextVolumeChange = false
        return
      }
      self.methodChannel?.invokeMethod("capturePressed", arguments: nil)
      self.snapVolume(to: self.restingVolume)
    }
  }
}
