import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_enqueuer.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../datasources/sync_queue_local_data_source.dart';
import '../models/sync_queue_item_record.dart';

/// Real, Hive-backed queue. [enqueueSession] upserts by wall id — this app
/// only ever tracks one active thing-to-sync per wall (matching
/// CaptureSessionRecord's own per-wall keying), so re-saving a wall's
/// capture round resets its existing queue entry rather than piling up
/// duplicates.
class SyncQueueRepositoryImpl implements SyncQueueRepository, SyncEnqueuer {
  SyncQueueRepositoryImpl(this._local);

  final SyncQueueLocalDataSource _local;

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
  Future<void> enqueueSession({
    required String wallId,
    required String siteId,
    required String displayName,
  }) async {
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
  );
}
