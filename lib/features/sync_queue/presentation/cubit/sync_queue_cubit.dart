import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../unassigned_walls/domain/repositories/unassigned_wall_repository.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../../domain/services/sync_queue_runner.dart';
import 'sync_queue_state.dart';

class SyncQueueCubit extends Cubit<SyncQueueState> {
  SyncQueueCubit(this._repository, this._runner, this._unassignedWalls)
    : super(const SyncQueueLoading()) {
    _subscribe();
  }

  final SyncQueueRepository _repository;
  final SyncQueueRunner _runner;
  final UnassignedWallRepository _unassignedWalls;
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

  /// Recovers a pre-fix local-id wall stuck in the queue (it can never sync
  /// as-is — see `SyncQueueRunner`'s local-id guard): moves its photos into
  /// features/unassigned_walls under [siteId], registers that metadata with
  /// the dashboard, and drops the now-redundant queue entry. The wall then
  /// continues through the normal Unassigned Walls resolution flow.
  Future<void> resolveOrphanedWall(String wallId, String siteId) async {
    await _unassignedWalls.migrateOrphanedGridCapture(wallId);
    await _unassignedWalls.syncMetadata(wallId, siteId: siteId);
    await _unassignedWalls.checkResolution(wallId);
    await _repository.discard(wallId);
  }

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
