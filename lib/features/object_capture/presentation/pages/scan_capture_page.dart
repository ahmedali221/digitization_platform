import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/camera/camera_widgets.dart';
import '../../../../core/camera/capture_camera_layout.dart';
import '../../../../core/camera/capture_camera_session.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/repositories/object_scan_repository.dart';
import '../../domain/services/camera_motion_source.dart';
import '../cubit/scan_capture_cubit.dart';
import '../cubit/scan_capture_state.dart';
import '../object_capture_routes.dart';
import '../widgets/coverage_ring.dart';
import '../widgets/scan_alignment_prompt.dart';
import '../widgets/scan_guidance_banner.dart';

/// The 3D scan camera. The operator walks slowly round the object; the app
/// takes each photograph itself and shows which sides are still to do.
class ScanCapturePage extends StatelessWidget {
  const ScanCapturePage({super.key, required this.routes});

  final ObjectCaptureRoutes routes;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanCaptureCubit(
        GetIt.instance<ObjectScanRepository>(),
        GetIt.instance<SiteRepository>(),
        GetIt.instance<CameraMotionSource>(),
        floorId: routes.floorId,
        wallId: routes.wallId,
      ),
      child: Scaffold(
        backgroundColor: AppColors.cameraBackground,
        body: SafeArea(
          child: BlocConsumer<ScanCaptureCubit, ScanCaptureState>(
            listenWhen: (previous, current) =>
                previous.phase != current.phase ||
                (current.failure != null &&
                    previous.failure != current.failure),
            listener: (context, state) {
              if (state.phase == ScanCapturePhase.finished) {
                context.pushReplacement(routes.scanStatus);
              } else if (state.failure != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.failure!)));
              }
            },
            buildWhen: (previous, current) => previous.phase != current.phase,
            builder: (context, state) => switch (state.phase) {
              ScanCapturePhase.objectMissing => const _ScanUnavailable(
                'This item could not be found.',
              ),
              ScanCapturePhase.noSensors => const _ScanUnavailable(
                'This phone has no motion sensors, so it cannot guide a 3D '
                'scan. Photograph the object with Free capture instead.',
              ),
              _ => const _ScanCamera(),
            },
          ),
        ),
      ),
    );
  }
}

/// Why there is no camera to show, on a plain page of its own: the scan
/// screen is otherwise dark, for the viewfinder.
class _ScanUnavailable extends StatelessWidget {
  const _ScanUnavailable(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox.expand(
        child: ErrorRetryView(
          message: message,
          onRetry: () => context.safePop(),
        ),
      ),
    );
  }
}

/// The live camera and its controls. Holds the camera session, which a
/// widget has to own: it follows the screen's lifecycle.
class _ScanCamera extends StatefulWidget {
  const _ScanCamera();

  @override
  State<_ScanCamera> createState() => _ScanCameraState();
}

class _ScanCameraState extends State<_ScanCamera> {
  late final CaptureCameraSession _camera;

  @override
  void initState() {
    super.initState();
    _camera = CaptureCameraSession(
      // Never the flash, whatever was last chosen on another screen: its
      // light moves with the phone, so the shine on the object would sit in
      // a different place in every photograph and none would match the next.
      initialFlashModeName: FlashMode.off.name,
      onFlashModeChanged: (_) {},
      onMessage: _showMessage,
      // The app decides when to shoot; a volume key has nothing to do here.
      onShutterPressed: () {},
    )..addListener(_onCameraChanged);
    _camera.start();
  }

  void _onCameraChanged() {
    if (!mounted) return;
    context.read<ScanCaptureCubit>().setCameraReady(
      _camera.loadState == CameraLoadState.ready && !_camera.switchingLens,
    );
    setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Takes the photograph the cubit asked for. When the camera turns out to
  /// be busy the request is handed back, and the cubit asks again.
  Future<void> _shoot() async {
    final cubit = context.read<ScanCaptureCubit>();
    if (!_camera.canShoot) {
      cubit.shotSkipped();
      return;
    }
    try {
      await _camera.capture((file) => _keep(cubit, file));
    } on Object {
      cubit.shotFailed();
    }
  }

  Future<void> _keep(ScanCaptureCubit cubit, XFile file) async {
    final folder = await cubit.incomingFolder();
    final path = p.join(
      folder,
      'shot_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.saveTo(path);
    await cubit.shotTaken(path);
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _finish(ScanCaptureState state) async {
    final cubit = context.read<ScanCaptureCubit>();
    final missing = ScanPlan.totalCells - state.coverage.capturedCount;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Finish the scan?',
      message:
          '$missing photographs of the plan are not taken yet. The model '
          'will be missing whatever they would have shown.',
      confirmLabel: 'Finish',
    );
    if (confirmed) await cubit.finish();
  }

  @override
  void dispose() {
    _camera
      ..removeListener(_onCameraChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCaptureCubit, ScanCaptureState>(
      listenWhen: (previous, current) =>
          previous.shotRequest != current.shotRequest,
      listener: (context, state) => _shoot(),
      builder: (context, state) {
        final ring = state.coverage.activeRing ?? ScanPlan.rings.length - 1;
        final cubit = context.read<ScanCaptureCubit>();
        return CaptureCameraLayout(
          viewfinder: CameraViewfinder(
            loadState: _camera.loadState,
            errorMessage: _camera.errorMessage,
            controller: _camera.controller,
            // No pinch to zoom: every photograph of a scan must come through
            // the same lens at the same zoom for the model to be built.
            onScaleStart: (_) {},
            onScaleUpdate: (_) {},
          ),
          topStart: CameraRoundButton(
            icon: Icons.arrow_back,
            iconColor: Colors.white,
            onTap: () => context.safePop(),
          ),
          topCenter: CameraPill(
            label: '${state.objectName} · ${ScanPlan.rings[ring].name}',
          ),
          zoom: state.phase != ScanCapturePhase.scanning
              ? ScanAlignmentPrompt(
                  isContinuing: state.phase == ScanCapturePhase.aligning,
                  onAligned: cubit.begin,
                )
              : ScanGuidanceBanner(
                  guidance: state.guidance,
                  ring: ScanPlan.rings[ring],
                ),
          shots: (_) => Center(
            child: CameraPill(
              label:
                  '${state.coverage.capturedCount} of ${ScanPlan.totalCells}',
            ),
          ),
          shutter: CoverageRing(
            coverage: state.coverage,
            ring: ring,
            azimuth: state.azimuth,
          ),
          finish: FilledButton(
            onPressed: state.coverage.capturedCount >= ScanPlan.minimumShots
                ? () => _finish(state)
                : null,
            child: const Text('Finish'),
          ),
        );
      },
    );
  }
}
