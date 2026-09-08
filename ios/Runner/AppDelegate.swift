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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
