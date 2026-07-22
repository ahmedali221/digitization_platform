import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/sync_queue_repository.dart';
import 'sync_queue_state.dart';

class SyncQueueCubit extends Cubit<SyncQueueState> {
  SyncQueueCubit(this._repository) : super(const SyncQueueLoading()) {
    _subscribe();
  }

  final SyncQueueRepository _repository;
  StreamSubscription? _subscription;

  void _subscribe() {
    emit(const SyncQueueLoading());
    _subscription = _repository.watchQueue().listen(
      (items) => emit(SyncQueueLoaded(items)),
      onError: (Object error) => emit(SyncQueueError(error.toString())),
    );
  }

  /// Re-enqueues a failed item; the repository's ticker picks it back up.
  void retry(String id) => _repository.retry(id);

  /// Re-subscribes to [SyncQueueRepository.watchQueue] after a load error.
  void reload() {
    _subscription?.cancel();
    _subscribe();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
