import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/sync_queue_repository.dart';
import '../../domain/services/sync_queue_runner.dart';
import 'sync_queue_state.dart';

class SyncQueueCubit extends Cubit<SyncQueueState> {
  SyncQueueCubit(this._repository, this._runner)
    : super(const SyncQueueLoading()) {
    _subscribe();
  }

  final SyncQueueRepository _repository;
  final SyncQueueRunner _runner;
  StreamSubscription? _subscription;

  void _subscribe() {
    emit(const SyncQueueLoading());
    _subscription = _repository.watchQueue().listen(
      (items) => emit(SyncQueueLoaded(items)),
      onError: (Object error) => emit(SyncQueueError(error.toString())),
    );
  }

  /// Re-queues a failed item, then immediately attempts to drain it.
  void retry(String id) {
    _repository.retry(id);
    unawaited(_runner.drainOne(id));
  }

  /// Manual "Sync now" — drains every queued/failed-and-retried item.
  Future<void> syncNow() => _runner.drainAll();

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
