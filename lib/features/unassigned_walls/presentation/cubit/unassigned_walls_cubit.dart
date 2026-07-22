import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/unassigned_wall_repository.dart';
import 'unassigned_walls_state.dart';

class UnassignedWallsCubit extends Cubit<UnassignedWallsState> {
  UnassignedWallsCubit(this._repository)
    : super(const UnassignedWallsLoading()) {
    _subscribe();
  }

  final UnassignedWallRepository _repository;
  StreamSubscription? _subscription;

  void _subscribe() {
    emit(const UnassignedWallsLoading());
    _subscription = _repository.watchUnassignedWalls().listen(
      (items) => emit(UnassignedWallsLoaded(items)),
      onError: (Object error) => emit(UnassignedWallsError(error.toString())),
    );
  }

  void retry() {
    _subscription?.cancel();
    _subscribe();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
