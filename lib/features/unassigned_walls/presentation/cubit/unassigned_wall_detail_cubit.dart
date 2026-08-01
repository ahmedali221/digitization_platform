import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/unassigned_wall.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import 'unassigned_wall_detail_state.dart';

/// Watches [UnassignedWallRepository]'s stream for one `localId` and drives
/// the sync/resolution/upload actions on `UnassignedWallDetailPage`.
class UnassignedWallDetailCubit extends Cubit<UnassignedWallDetailState> {
  UnassignedWallDetailCubit(this._repository, this._localId)
    : super(const UnassignedWallDetailLoading()) {
    _subscription = _repository.watchUnassignedWalls().listen(
      _onWallsChanged,
      onError: (Object error) =>
          emit(UnassignedWallDetailError(error.toString())),
    );
  }

  final UnassignedWallRepository _repository;
  final String _localId;
  late final StreamSubscription<List<UnassignedWall>> _subscription;

  void _onWallsChanged(List<UnassignedWall> walls) {
    UnassignedWall? match;
    for (final wall in walls) {
      if (wall.localId == _localId) {
        match = wall;
        break;
      }
    }
    if (match == null) {
      emit(const UnassignedWallDetailNotFound());
      return;
    }
    final current = state;
    emit(
      current is UnassignedWallDetailLoaded
          ? current.copyWith(wall: match)
          : UnassignedWallDetailLoaded(match),
    );
  }

  /// `POST /sync/unassigned` then an immediate `GET /sync/mappings` check —
  /// registering metadata and checking for a resolution are cheap enough to
  /// do back-to-back rather than making the operator tap twice.
  Future<bool> syncToDashboard() async {
    final current = state;
    if (current is! UnassignedWallDetailLoaded) return false;
    emit(current.copyWith(syncing: true));
    try {
      await _repository.syncMetadata(_localId);
      await _repository.checkResolution(_localId);
      return true;
    } on Object catch (_) {
      return false;
    } finally {
      final latest = state;
      if (latest is UnassignedWallDetailLoaded) {
        emit(latest.copyWith(syncing: false));
      }
    }
  }

  Future<bool> uploadPhotos() async {
    final current = state;
    if (current is! UnassignedWallDetailLoaded) return false;
    emit(current.copyWith(syncing: true));
    try {
      await _repository.promoteToRealWall(_localId);
      return true;
    } on Object catch (_) {
      return false;
    } finally {
      final latest = state;
      if (latest is UnassignedWallDetailLoaded) {
        emit(latest.copyWith(syncing: false));
      }
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
