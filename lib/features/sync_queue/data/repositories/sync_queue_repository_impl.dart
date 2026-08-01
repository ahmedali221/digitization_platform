import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_enqueuer.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../../domain/services/sync_queue_runner.dart';
import '../datasources/sync_queue_local_data_source.dart';
import '../models/sync_queue_item_record.dart';

/// Real, Hive-backed queue. [enqueueSession] upserts by wall id — this app
/// only ever tracks one active thing-to-sync per wall (matching
/// CaptureSessionRecord's own per-wall keying), so re-saving a wall's
/// capture round resets its existing queue entry rather than piling up
/// duplicates.
class SyncQueueRepositoryImpl implements SyncQueueRepository, SyncEnqueuer {
  SyncQueueRepositoryImpl(this._local, this._runner);

  final SyncQueueLocalDataSource _local;
  final SyncQueueRunner _runner;

  @override
  Stream<List<SyncItem>> watchQueue() =>
      _local.watchAll().map((records) => records.map(_toEntity).toList());

  @override
  void retry(String id) {
    final record = _local.get(id);
    if (record == null) return;
    record
      ..status = 'queued'
      ..progress = 0
      ..lastError = null;
    _local.put(record);
  }

  @override
  Future<void> discard(String id) => _local.delete(id);

  @override
  Future<void> enqueueSession({
    required String wallId,
    required String siteId,
    required String displayName,
  }) async {
    if (wallId.startsWith('local_')) {
      // A local-only wall id has no corresponding `walls` row on the server
      // yet — the sync endpoints will always 422 it. Callers must resolve
      // it via features/unassigned_walls before enqueueing a session.
      debugPrint(
        'SyncQueueRepositoryImpl: refusing to enqueue unresolved local wall '
        '$wallId',
      );
      return;
    }

    final existing = _local.get(wallId);
    await _local.put(
      SyncQueueItemRecord(
        id: wallId,
        sessionId: wallId,
        wallId: wallId,
        siteId: siteId,
        displayName: displayName,
        status: 'queued',
        progress: 0,
        attempts: existing?.attempts ?? 0,
        createdAt: existing?.createdAt ?? DateTime.now(),
      ),
    );
    // Attempt the upload right away rather than waiting for a reconnect
    // event, the periodic background task, or a manual "Sync now" tap — a
    // capture round shouldn't sit purely local until one of those happens to
    // fire. Fire-and-forget: failures just leave the item queued/failed for
    // the existing retry paths to pick up.
    unawaited(_runner.drainOne(wallId));
  }

  SyncItem _toEntity(SyncQueueItemRecord record) => SyncItem(
    id: record.id,
    name: record.displayName,
    status: switch (record.status) {
      'uploading' => SyncItemStatus.uploading,
      'confirmed' => SyncItemStatus.confirmed,
      'failed' => SyncItemStatus.failed,
      _ => SyncItemStatus.queued,
    },
    progress: record.progress,
    reason: record.lastError,
  );
}
