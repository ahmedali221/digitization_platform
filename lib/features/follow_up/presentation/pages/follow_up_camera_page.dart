import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import '../../../../core/camera/camera_widgets.dart';
import '../../../../core/camera/capture_camera_layout.dart';
import '../../../../core/camera/capture_camera_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../grid_capture/data/datasources/camera_preferences_local_data_source.dart';
import '../widgets/captured_photo_review.dart';
import '../widgets/captured_photo_thumbnail.dart';

/// Takes several shots of one thing, kept in [folder], and pops with their
/// paths. A hard-to-photograph surface usually needs a few tries, and choosing
/// afterwards beats judging on a small screen in sunlight. A shot can be opened
/// from its thumbnail and deleted, to take another in its place.
class FollowUpCameraPage extends StatefulWidget {
  const FollowUpCameraPage({super.key, required this.title, required this.folder});

  final String title;
  final String folder;

  @override
  State<FollowUpCameraPage> createState() => _FollowUpCameraPageState();
}

class _FollowUpCameraPageState extends State<FollowUpCameraPage> {
  late final CaptureCameraSession _camera;
  final List<String> _shots = [];

  final CameraPreferencesLocalDataSource _preferences =
      GetIt.instance<CameraPreferencesLocalDataSource>();

  @override
  void initState() {
    super.initState();
    _camera = CaptureCameraSession(
      initialFlashModeName: _preferences.getFlashModeName(),
      onFlashModeChanged: (name) => unawaited(_preferences.setFlashModeName(name)),
      onMessage: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      onShutterPressed: _shoot,
    )..addListener(_onCameraChanged);
    _camera.start();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  /// The volume key and Bluetooth remote still reach here under a preview or a
  /// confirmation, where a photograph would be taken unseen.
  Future<void> _shoot() async {
    if (ModalRoute.isCurrentOf(context) ?? false) await _camera.capture(_keep);
  }

  Future<void> _keep(XFile file) async {
    final name = 'shot_${_shots.length + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = p.join(widget.folder, name);
    await file.saveTo(path);
    if (mounted) setState(() => _shots.add(path));
  }

  Future<void> _review(String path) async {
    final decision = await reviewCapturedPhoto(context, path);
    if (decision == CapturedPhotoDecision.delete && mounted) await _remove(path);
  }

  Future<void> _remove(String path) async {
    setState(() => _shots.remove(path));
    final file = File(path);
    if (await file.exists()) await file.delete();
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
    return Scaffold(
      backgroundColor: AppColors.cameraBackground,
      body: SafeArea(
        child: CaptureCameraLayout(
          viewfinder: CameraViewfinder(
            loadState: _camera.loadState,
            errorMessage: _camera.errorMessage,
            controller: _camera.controller,
            onScaleStart: _camera.onScaleStart,
            onScaleUpdate: _camera.onScaleUpdate,
          ),
          topStart: CameraRoundButton(
            icon: Icons.arrow_back,
            iconColor: Colors.white,
            onTap: () => Navigator.of(context).pop(),
          ),
          topCenter: CameraPill(label: widget.title),
          topEnd: CameraFlashButton(mode: _camera.flashMode, onTap: _camera.cycleFlash),
          zoom: _camera.loadState == CameraLoadState.ready
              ? CameraZoomPresets(
                  currentZoom: _camera.displayZoom,
                  minimumZoom: _camera.primaryMinimumZoom,
                  maximumZoom: _camera.primaryMaximumZoom,
                  hasUltraWideLens: _camera.canReachUltraWide,
                  onSelect: _camera.selectZoomPreset,
                )
              : null,
          shots: (axis) => _ShotStrip(
            axis: axis,
            shots: _shots,
            onOpen: _camera.capturing ? null : _review,
          ),
          shutter: CameraShutterButton(onTap: _camera.canShoot ? _shoot : null),
          finish: FilledButton(
            onPressed: _shots.isEmpty || _camera.capturing
                ? null
                : () => Navigator.of(context).pop(List<String>.of(_shots)),
            child: Text('Done (${_shots.length})'),
          ),
        ),
      ),
    );
  }
}

/// The shots taken so far, newest first: the strip only fits a couple, and the
/// one just taken is the one to check.
class _ShotStrip extends StatelessWidget {
  const _ShotStrip({required this.axis, required this.shots, required this.onOpen});

  final Axis axis;
  final List<String> shots;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      scrollDirection: axis,
      shrinkWrap: axis == Axis.vertical,
      itemCount: shots.length,
      separatorBuilder: (_, _) => const SizedBox.square(dimension: AppSpacing.sm),
      itemBuilder: (context, index) {
        final path = shots[shots.length - 1 - index];
        return Center(
          child: CapturedPhotoThumbnail(
            key: ValueKey(path),
            path: path,
            onTap: onOpen == null ? null : () => onOpen!(path),
          ),
        );
      },
    );
    return axis == Axis.horizontal ? SizedBox(height: CapturedPhotoThumbnail.size, child: list) : list;
  }
}
