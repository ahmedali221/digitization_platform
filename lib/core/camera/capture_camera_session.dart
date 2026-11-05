import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../hardware/capture_button_channel.dart';
import '../hardware/lens_info_channel.dart';

enum CameraLoadState { loading, ready, error }

/// The live camera behind a capture screen: lens, zoom, flash, shutter and
/// app-lifecycle handling, shared by the grid camera and the follow-up camera.
/// A screen listens to it and supplies what to do with each photo through
/// [capture]; everything about keeping the native session safe lives here.
class CaptureCameraSession extends ChangeNotifier with WidgetsBindingObserver {
  CaptureCameraSession({
    required String? initialFlashModeName,
    required this.onFlashModeChanged,
    required this.onMessage,
    required this.onShutterPressed,
  }) {
    flashMode = flashModeCycle.firstWhere(
      (mode) => mode.name == initialFlashModeName,
      orElse: () => FlashMode.off,
    );
  }

  /// Persists the operator's choice, so it carries to the next screen.
  final void Function(String flashModeName) onFlashModeChanged;

  /// A non-fatal problem worth telling the operator about.
  final void Function(String message) onMessage;

  /// The volume key or Bluetooth remote was pressed.
  final void Function() onShutterPressed;

  /// Tolerance when matching a zoom level to one of the preset pills.
  static const double zoomMatchTolerance = 0.05;

  CameraController? controller;
  CameraLoadState loadState = CameraLoadState.loading;
  String? errorMessage;
  bool capturing = false;

  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _currentZoom = 1;
  double _appliedZoom = 1;
  double _baseZoom = 1;
  double? _pendingZoom;
  bool _applyingZoom = false;

  // The `camera` plugin defaults every controller to FlashMode.auto, which
  // fires (or doesn't) per-shot based on the plugin's own ambient-light
  // metering — inconsistent lighting between grid cells hurts the
  // neighbour-matching quality score, and reads as "the flash turns on by
  // itself" to the operator. Defaulting to off makes capture predictable;
  // the button cycles off -> auto -> torch (steady on) for whoever wants it.
  late FlashMode flashMode;
  static const flashModeCycle = [FlashMode.off, FlashMode.auto, FlashMode.torch];

  // Guards against overlapping camera-controller operations — e.g. tapping
  // a zoom preset mid-capture, or firing the shutter mid-lens-switch — which
  // is what let a `setZoomLevel`/`takePicture` call race a concurrent
  // `dispose()` on the same native session and crash on iOS (AVFoundation
  // has no protection against a platform call landing on a session that's
  // being torn down at the same moment).
  bool switchingLens = false;

  // Set synchronously at the top of `dispose()` so an in-flight async method's
  // next `await` sees it immediately and stops issuing further native calls
  // against a controller this session is in the middle of tearing down.
  bool _disposed = false;

  // The primary lens's own range, cached once at startup — used to decide
  // which zoom presets to show regardless of which physical lens is
  // currently active (switching to the ultra-wide lens temporarily reports
  // its own native ~1x-3x range, which must not hide the 1x/2x presets).
  double primaryMinimumZoom = 1;
  double primaryMaximumZoom = 1;
  List<CameraDescription> _backCameras = [];

  // Below 1x is optical, not digital: it requires physically switching to an
  // ultra-wide lens. Only set when the primary lens can't already reach
  // below 1x itself (e.g. iOS's fused virtual multi-camera device already
  // covers that case without a switch) and [LensInfoChannel] confirmed the
  // device actually has a distinct ultra-wide lens to switch to.
  CameraDescription? _ultraWideCamera;
  bool _onUltraWideLens = false;

  // The ultra-wide lens's zoom multiplier relative to the primary lens, as
  // reported by [LensInfoChannel] (e.g. 0.52 on a device whose "0.5x" lens
  // isn't exactly half). Falls back to the conventional 0.5 when unknown.
  double _ultraWideZoomRatio = 0.5;

  double get displayZoom =>
      _onUltraWideLens ? _currentZoom * _ultraWideZoomRatio : _currentZoom;

  // True whenever 0.5x is actually reachable — either the primary lens
  // already natively zooms below 1x (no switch needed, e.g. iOS's fused
  // virtual multi-camera device), or there's a separate ultra-wide
  // CameraDescription to switch to.
  bool get canReachUltraWide =>
      _ultraWideCamera != null ||
      primaryMinimumZoom <= 0.5 + zoomMatchTolerance;

  bool get canShoot =>
      loadState == CameraLoadState.ready && !capturing && !switchingLens;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    CaptureButtonChannel.listen(onShutterPressed);
    _initializeCamera();
  }

  /// Releases the camera sensor the instant the app stops being the
  /// foreground app (`inactive`, not the later `paused`, matching the
  /// `camera` plugin's own reference example — `inactive` fires immediately
  /// on both platforms, `paused` can lag behind it), and re-acquires it on
  /// `resumed`. Without this, backgrounding mid-capture (a call, the home
  /// button, switching apps) leaves the sensor and preview pipeline running
  /// for as long as the operator is away — a battery drain with nothing to
  /// show for it, since nothing is on screen to look at the preview. Always
  /// re-acquires the primary lens on resume rather than remembering an
  /// active ultra-wide switch — simpler and reuses the exact same
  /// (well-tested) startup path instead of a second controller-creation
  /// route, at the cost of the operator having to re-select ultra-wide if
  /// they were on it before backgrounding.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      unawaited(_releaseCameraForBackground());
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null || loadState != CameraLoadState.loading) return;
      _initializeCamera();
    }
  }

  /// Disposes [controller] once any native call already in flight
  /// (capturing, zooming, switching lens) has settled — never mid-call.
  /// Racing a `dispose()` against an in-flight native call on the same
  /// controller is exactly what crashed AVFoundation before (see
  /// `_disposed`'s doc comment); backgrounding is common enough mid-capture
  /// (an incoming call, the home button) that this can't skip the same wait
  /// [capture]/`_switchLens` already do.
  Future<void> _releaseCameraForBackground() async {
    if (controller == null) return;
    while (capturing || switchingLens || _applyingZoom) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    if (_disposed) return;
    // Re-read rather than reuse a reference captured before the wait — a
    // lens switch may have replaced the controller with a different instance
    // while this was waiting, and that's the one that now needs disposing.
    final current = controller;
    if (current == null) return;
    controller = null;
    loadState = CameraLoadState.loading;
    notifyListeners();
    await current.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (_disposed) return;
      if (cameras.isEmpty) {
        loadState = CameraLoadState.error;
        errorMessage = 'No camera was found on this device.';
        notifyListeners();
        return;
      }
      final backCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();
      // Ask the platform which back lens is actually primary/ultra-wide —
      // see LensInfoChannel's doc for why guessing from list order/name
      // (the old approach) misidentifies lenses on several devices.
      final lensRoles = await LensInfoChannel.getBackLensRoles();
      final primaryCamera =
          _findCameraByName(backCameras, lensRoles?.primaryName) ??
          (backCameras.isNotEmpty ? backCameras.first : cameras.first);
      final ultraWideCamera = _findCameraByName(
        backCameras,
        lensRoles?.ultraWideName,
      );
      final newController = CameraController(
        primaryCamera,
        // Max, not high: these photos are what gets stitched, and the
        // analyzer's sharpness score reads them at full size. Keeping the
        // analyzer fast is its own job (CaptureQualityConfig.analysisMaxLongSide),
        // not a reason to capture less.
        ResolutionPreset.max,
        enableAudio: false,
      );
      await newController.initialize();
      await _applyFlashMode(newController);
      final minimumZoom = await newController.getMinZoomLevel();
      final maximumZoom = await newController.getMaxZoomLevel();
      final initialZoom = 1.0.clamp(minimumZoom, maximumZoom).toDouble();
      await newController.setZoomLevel(initialZoom);
      if (_disposed) {
        await newController.dispose();
        return;
      }
      controller = newController;
      loadState = CameraLoadState.ready;
      _backCameras = backCameras;
      _ultraWideCamera = ultraWideCamera;
      _ultraWideZoomRatio = lensRoles?.ultraWideZoomRatio ?? 0.5;
      _minimumZoom = minimumZoom;
      _maximumZoom = maximumZoom;
      primaryMinimumZoom = minimumZoom;
      primaryMaximumZoom = maximumZoom;
      _currentZoom = initialZoom;
      _appliedZoom = initialZoom;
      _baseZoom = initialZoom;
      _onUltraWideLens = false;
      notifyListeners();
    } catch (error) {
      if (_disposed) return;
      loadState = CameraLoadState.error;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  static CameraDescription? _findCameraByName(
    List<CameraDescription> cameras,
    String? name,
  ) {
    if (name == null) return null;
    for (final camera in cameras) {
      if (camera.name == name) return camera;
    }
    return null;
  }

  /// Switches the live controller to a different physical back lens (e.g.
  /// primary <-> ultra-wide). The previous controller keeps rendering until
  /// the new one has initialized, so the viewfinder never has to fall back
  /// to a loading state mid-switch.
  Future<void> _switchLens(
    CameraDescription description, {
    required bool isUltraWide,
  }) async {
    // Re-entrancy guard: two overlapping switches (e.g. a double-tap across
    // presets before the first finishes initializing) would otherwise create
    // a second new controller while the first is still being wired up, and
    // both could end up racing to dispose the same previous controller.
    if (switchingLens) return;
    switchingLens = true;
    final previousController = controller;
    try {
      final newController = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await newController.initialize();
      await _applyFlashMode(newController);
      final minimumZoom = await newController.getMinZoomLevel();
      final maximumZoom = await newController.getMaxZoomLevel();
      await newController.setZoomLevel(minimumZoom);
      if (_disposed) {
        await newController.dispose();
        return;
      }
      // A pinch/preset zoom requested just before this switch may still have
      // a `setZoomLevel` call in flight against `previousController` —
      // disposing it while that native call is still executing is what let
      // iOS crash (AVFoundation has no protection against a platform call
      // landing on a session that's being torn down at the same instant).
      while (_applyingZoom) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_disposed) {
        await newController.dispose();
        return;
      }
      controller = newController;
      _minimumZoom = minimumZoom;
      _maximumZoom = maximumZoom;
      _currentZoom = minimumZoom;
      _appliedZoom = minimumZoom;
      _baseZoom = minimumZoom;
      _onUltraWideLens = isUltraWide;
      notifyListeners();
      await previousController?.dispose();
    } on CameraException catch (error) {
      if (!_disposed) {
        onMessage(
          'Could not switch camera lens: ${error.description ?? error.code}',
        );
      }
    } finally {
      switchingLens = false;
    }
  }

  Future<void> selectZoomPreset(double level) async {
    if (loadState != CameraLoadState.ready || capturing || switchingLens) {
      return;
    }
    final wantsUltraWide = level < 1;
    if (wantsUltraWide && _ultraWideCamera != null) {
      if (!_onUltraWideLens) {
        await _switchLens(_ultraWideCamera!, isUltraWide: true);
      }
      return;
    }
    if (!wantsUltraWide && _onUltraWideLens) {
      await _switchLens(_backCameras.first, isUltraWide: false);
    }
    _requestZoom(level);
  }

  /// Takes a photo and hands it to [handle], holding [capturing] until that
  /// finishes so the shutter can't fire again over it.
  Future<void> capture(Future<void> Function(XFile file) handle) async {
    final current = controller;
    if (current == null || capturing || switchingLens) return;
    capturing = true;
    notifyListeners();
    try {
      // On iOS, the primary "camera" is often a virtual multi-lens device
      // whose zoom crosses physical lenses internally as `videoZoomFactor`
      // changes — capturing while that transition is still in flight (right
      // after a pinch/preset zoom) is a known source of intermittent
      // AVFoundation crashes on those devices, so wait for it to settle
      // first rather than firing the shutter concurrently with it.
      while (_applyingZoom) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_disposed) return;
      final file = await current.takePicture();
      if (_disposed) return;
      await handle(file);
    } finally {
      if (!_disposed) {
        capturing = false;
        notifyListeners();
      }
    }
  }

  void onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || switchingLens || capturing) return;
    _requestZoom(_baseZoom * details.scale);
  }

  void _requestZoom(double requestedZoom) {
    if (loadState != CameraLoadState.ready) return;
    final zoom = requestedZoom.clamp(_minimumZoom, _maximumZoom).toDouble();
    if ((zoom - _currentZoom).abs() < 0.01) return;

    _currentZoom = zoom;
    notifyListeners();
    _pendingZoom = zoom;
    if (!_applyingZoom) unawaited(_applyPendingZoom());
  }

  Future<void> _applyPendingZoom() async {
    _applyingZoom = true;
    try {
      while (!_disposed && _pendingZoom != null) {
        final zoom = _pendingZoom!;
        _pendingZoom = null;
        await controller?.setZoomLevel(zoom);
        _appliedZoom = zoom;
      }
    } on CameraException catch (error) {
      _pendingZoom = null;
      if (!_disposed) {
        _currentZoom = _appliedZoom;
        notifyListeners();
        onMessage(
          'Could not change camera zoom: ${error.description ?? error.code}',
        );
      }
    } finally {
      _applyingZoom = false;
      if (!_disposed && _pendingZoom != null) {
        unawaited(_applyPendingZoom());
      }
    }
  }

  /// Applies [flashMode] to a just-initialized controller — both the startup
  /// controller and every lens-switch controller default to the plugin's own
  /// FlashMode.auto, so this has to run after every `initialize()` to keep
  /// the operator's choice in effect across a lens switch. Some devices throw
  /// when asked for a flash mode they don't support — swallowed rather than
  /// surfaced, since falling back to whatever the plugin already applied is
  /// harmless.
  Future<void> _applyFlashMode(CameraController target) async {
    try {
      await target.setFlashMode(flashMode);
    } on CameraException catch (error) {
      debugPrint(
        'CaptureCameraSession: setFlashMode(${flashMode.name}) failed: '
        '${error.description ?? error.code}',
      );
    }
  }

  /// Cycles off -> auto -> torch (steady on) -> off. Torch (rather than
  /// FlashMode.always) is offered as the "on" option so lighting stays
  /// identical across every shot in the grid — an operator who wants
  /// consistent illumination for neighbour-matching shouldn't have to
  /// depend on the plugin's per-shot auto-exposure decision.
  Future<void> cycleFlash() async {
    final current = controller;
    if (current == null || capturing || switchingLens) return;
    final next =
        flashModeCycle[(flashModeCycle.indexOf(flashMode) + 1) %
            flashModeCycle.length];
    try {
      await current.setFlashMode(next);
      if (_disposed) return;
      flashMode = next;
      notifyListeners();
      onFlashModeChanged(next.name);
    } on CameraException catch (error) {
      if (!_disposed) {
        onMessage('Could not change flash: ${error.description ?? error.code}');
      }
    }
  }

  @override
  void dispose() {
    // Set first, synchronously, so any in-flight async camera method's next
    // `await` sees it before this method disposes the controller out from
    // under it — see `_disposed`'s doc comment.
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    CaptureButtonChannel.stop();
    controller?.dispose();
    super.dispose();
  }
}
