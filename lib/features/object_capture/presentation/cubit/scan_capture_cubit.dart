import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/repositories/object_scan_repository.dart';
import '../../domain/services/auto_shutter.dart';
import '../../domain/services/camera_motion_source.dart';
import 'scan_capture_state.dart';

/// Leads a 3D scan: reads where the camera points many times a second,
/// decides when a photograph is due, and keeps count of what is covered.
/// The operator only moves the phone round the object.
class ScanCaptureCubit extends Cubit<ScanCaptureState> {
  ScanCaptureCubit(
    this._repository,
    this._siteRepository,
    this._motionSource, {
    required this.floorId,
    required this.wallId,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       super(const ScanCaptureState()) {
    _open();
  }

  static const _shotFailedMessage =
      'That photograph could not be kept. Check the free space on this phone.';

  final ObjectScanRepository _repository;
  final SiteRepository _siteRepository;
  final CameraMotionSource _motionSource;
  final DateTime Function() _clock;
  final String floorId;
  final String wallId;

  StreamSubscription<CameraMotion>? _motion;

  /// Where the sensors said the camera pointed when the scan's first
  /// photograph was taken: every other angle is counted from it.
  double? _originAzimuth;
  double _latestAzimuth = 0;

  /// The slice a requested photograph is for, until it is kept or fails.
  ScanCell? _awaited;
  bool _cameraReady = false;

  /// Since when the phone has been still without a break, or null while it
  /// is moving.
  DateTime? _stillSince;

  void _open() {
    final wall = _siteRepository.findWall(floorId, wallId);
    if (wall == null) {
      emit(state.copyWith(phase: ScanCapturePhase.objectMissing));
      return;
    }
    final coverage = _repository.getScan(wallId)?.coverage;
    emit(
      state.copyWith(
        objectName: wall.name,
        coverage: coverage,
        phase: coverage == null || coverage.capturedCount == 0
            ? ScanCapturePhase.ready
            : ScanCapturePhase.aligning,
      ),
    );
    _motion = _motionSource.watch().listen(
      _onMotion,
      onError: (Object _) =>
          emit(state.copyWith(phase: ScanCapturePhase.noSensors)),
    );
  }

  /// The operator has the object in the frame from where the scan begins,
  /// or began: every angle is counted from this direction on.
  void begin() {
    _originAzimuth = _latestAzimuth;
    emit(state.copyWith(phase: ScanCapturePhase.scanning));
  }

  /// Whether the camera can take a photograph right now. None is asked for
  /// while it cannot: a camera still starting is not a failed photograph.
  void setCameraReady(bool isReady) => _cameraReady = isReady;

  Future<String> incomingFolder() => _repository.incomingFolder(wallId);

  /// The screen took the photograph it was asked for, at [shotPath].
  Future<void> shotTaken(String shotPath) async {
    final cell = _awaited;
    if (cell == null) return;
    try {
      await _repository.addShot(
        floorId: floorId,
        wallId: wallId,
        shotPath: shotPath,
        cell: cell,
      );
    } on Object {
      shotFailed();
      return;
    }
    _awaited = null;
    final coverage = state.coverage.withCaptured(cell);
    emit(state.copyWith(coverage: coverage));
    // Nothing left to ask for: the scan hands itself over.
    if (coverage.activeRing == null) await finish();
  }

  void shotFailed() {
    _awaited = null;
    emit(state.copyWith(failure: _shotFailedMessage));
  }

  /// The camera was busy after all; the photograph is asked for again.
  void shotSkipped() => _awaited = null;

  /// Hands the scan over for upload. A level ring left incomplete means the
  /// object could not be walked all the way round, which the server is told
  /// so that it does not hold the missing side against the scan.
  Future<void> finish() async {
    if (state.phase == ScanCapturePhase.finished) return;
    await _motion?.cancel();
    await _repository.finish(
      floorId: floorId,
      wallId: wallId,
      fullCircle: state.coverage.isRingComplete(0),
    );
    emit(state.copyWith(phase: ScanCapturePhase.finished));
  }

  void _onMotion(CameraMotion motion) {
    _latestAzimuth = motion.direction.azimuth;
    if (state.phase != ScanCapturePhase.scanning) return;

    final direction = CameraDirection(
      azimuth: ScanPlan.normalise(motion.direction.azimuth - _originAzimuth!),
      elevation: motion.direction.elevation,
    );
    final guidance = AutoShutter.guide(
      coverage: state.coverage,
      direction: direction,
      turningRate: motion.turningRate,
    );

    final now = _clock();
    if (motion.turningRate >= AutoShutter.stillBelow) {
      _stillSince = null;
    } else {
      _stillSince ??= now;
    }
    final hasSettled =
        _stillSince != null &&
        now.difference(_stillSince!) >= AutoShutter.settleTime;

    var shotRequest = state.shotRequest;
    if (guidance == ScanGuidance.shoot &&
        hasSettled &&
        _awaited == null &&
        _cameraReady) {
      _awaited = ScanPlan.cellAt(state.coverage.activeRing!, direction.azimuth);
      shotRequest++;
    }
    // Whole degrees: the sensors report dozens of times a second, and the
    // screen has nothing new to draw for a fraction of a degree.
    emit(
      state.copyWith(
        guidance: guidance,
        azimuth: direction.azimuth.round() % 360,
        shotRequest: shotRequest,
      ),
    );
  }

  @override
  Future<void> close() {
    _motion?.cancel();
    return super.close();
  }
}
