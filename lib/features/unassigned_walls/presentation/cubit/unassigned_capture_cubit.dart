import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/unassigned_capture_local_data_source.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import 'unassigned_capture_state.dart';

/// Backs the flat (no-grid) camera screen for an unassigned wall. Mirrors
/// `CaptureSessionCubit`'s split — file I/O goes through
/// `UnassignedCaptureLocalDataSource` directly, then the resulting
/// `filePath`/`sha256` is handed to `UnassignedWallRepository` — but with no
/// per-cell/grid concept: shots just append to one flat list.
class UnassignedCaptureCubit extends Cubit<UnassignedCaptureState> {
  UnassignedCaptureCubit(this._repository, this._localDataSource)
    : super(const UnassignedCaptureLoading());

  final UnassignedWallRepository _repository;
  final UnassignedCaptureLocalDataSource _localDataSource;
  String _localId = '';

  Future<void> init({
    required String localId,
    required String siteId,
    required String floorId,
  }) async {
    _localId = localId;
    emit(const UnassignedCaptureLoading());
    try {
      await _localDataSource.ensure(
        localId: localId,
        siteId: siteId,
        floorId: floorId,
      );
      _emitFromRecord();
    } catch (error) {
      emit(UnassignedCaptureError(error.toString()));
    }
  }

  Future<void> takePhoto(XFile capturedFile) async {
    final record = _localDataSource.get(_localId);
    if (record == null) return;
    final shotNumber = record.shots.length + 1;

    final saved = await _localDataSource.saveShot(
      localId: _localId,
      shotNumber: shotNumber,
      capturedFile: capturedFile,
    );
    await _repository.appendShot(_localId, saved.path, saved.sha256);
    _emitFromRecord();
  }

  Future<void> deletePhoto(String filePath) async {
    await _localDataSource.deleteShot(localId: _localId, filePath: filePath);
    await _repository.removeShot(_localId, filePath);
    _emitFromRecord();
  }

  void _emitFromRecord() {
    final record = _localDataSource.get(_localId);
    emit(
      UnassignedCaptureLoaded(
        localId: _localId,
        shotPaths: record?.shots ?? const [],
      ),
    );
  }
}
