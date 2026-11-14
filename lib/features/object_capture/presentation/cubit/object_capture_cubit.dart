import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/entities/object_capture.dart';
import '../../domain/entities/object_scan.dart';
import '../../domain/repositories/object_capture_repository.dart';
import '../../domain/repositories/object_scan_repository.dart';
import 'object_capture_state.dart';

/// Drives the object capture screens for one object: keeps their view of
/// its photographs live and carries out what the operator does to them.
class ObjectCaptureCubit extends Cubit<ObjectCaptureState> {
  ObjectCaptureCubit(
    this._repository,
    this._scanRepository,
    this._siteRepository, {
    required this.floorId,
    required this.wallId,
  }) : super(const ObjectCaptureLoading()) {
    final wall = _siteRepository.findWall(floorId, wallId);
    if (wall == null) {
      emit(const ObjectCaptureNotFound());
      return;
    }
    emit(
      ObjectCaptureLoaded(
        wall: wall,
        capture: _repository.getCapture(wallId),
        scan: _scanRepository.getScan(wallId),
      ),
    );
    _subscription = _repository.watchCapture(wallId).listen(_onCaptureChanged);
    _scanSubscription = _scanRepository
        .watchScan(wallId)
        .listen(_onScanChanged);
  }

  static const _keepFailedMessage =
      'That photograph could not be kept. Check the free space on this phone '
      'and take it again.';

  final ObjectCaptureRepository _repository;
  final ObjectScanRepository _scanRepository;
  final SiteRepository _siteRepository;
  final String floorId;
  final String wallId;
  StreamSubscription<ObjectCapture>? _subscription;
  StreamSubscription<ObjectScan?>? _scanSubscription;

  void _onCaptureChanged(ObjectCapture capture) {
    final current = state;
    if (current is ObjectCaptureLoaded) {
      emit(current.copyWith(capture: capture));
    }
  }

  void _onScanChanged(ObjectScan? scan) {
    final current = state;
    if (current is ObjectCaptureLoaded) emit(current.copyWith(scan: scan));
  }

  Future<String> incomingFolder() => _repository.incomingFolder(wallId);

  Future<void> keepSidePhoto(ObjectSide side, String shotPath) => _guarded(
    () => _repository.setSidePhoto(
      floorId: floorId,
      wallId: wallId,
      side: side,
      shotPath: shotPath,
    ),
  );

  Future<void> keepFreePhotos(List<String> shotPaths) => _guarded(
    () => _repository.addFreePhotos(
      floorId: floorId,
      wallId: wallId,
      shotPaths: shotPaths,
    ),
  );

  /// Picks up shots the camera wrote that were never handed over. See
  /// [ObjectCaptureRepository.adoptStrayShots].
  Future<void> adoptStrayShots() => _guarded(
    () => _repository.adoptStrayShots(floorId: floorId, wallId: wallId),
  );

  Future<void> setComment(String photoPath, String comment) => _repository
      .setComment(wallId: wallId, photoPath: photoPath, comment: comment);

  Future<void> deletePhoto(String photoPath) =>
      _repository.deletePhoto(wallId: wallId, photoPath: photoPath);

  Future<void> save() => _repository.save(floorId: floorId, wallId: wallId);

  /// Keeping a shot touches the disk, which can be full. The photograph is
  /// still where the camera wrote it, so the failure is reported rather than
  /// thrown past the screen.
  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      final current = state;
      if (current is ObjectCaptureLoaded) {
        emit(current.copyWith(failure: _keepFailedMessage));
      }
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _scanSubscription?.cancel();
    return super.close();
  }
}
