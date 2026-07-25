import '../../../../core/errors/failure.dart';
import '../../../../core/storage/device_id_provider.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../../grid_capture/data/datasources/capture_session_local_data_source.dart';
import '../../data/datasources/sync_queue_local_data_source.dart';
import '../../data/datasources/sync_remote_data_source.dart';
import '../../data/models/sync_queue_item_record.dart';

/// Drains the sync queue: register the grid manifest, upload every photo,
/// confirm — deleting the local backup copy only once confirm succeeds
/// (Invariant 1). Network/5xx failures stay `queued` so the next drain
/// (manual "Sync now" or the background task) retries automatically; a 422
/// validation failure is terminal (`failed`) and needs the operator to fix
/// the session before a manual retry, per the contract's documented
/// guidance — never blind-retried.
class SyncQueueRunner {
  SyncQueueRunner({
    required SyncQueueLocalDataSource queueLocal,
    required CaptureSessionLocalDataSource sessionLocal,
    required SyncRemoteDataSource remote,
    required DeviceIdProvider deviceIdProvider,
    required DirectoryManager directoryManager,
  }) : _queueLocal = queueLocal,
       _sessionLocal = sessionLocal,
       _remote = remote,
       _deviceIdProvider = deviceIdProvider,
       _directoryManager = directoryManager;

  final SyncQueueLocalDataSource _queueLocal;
  final CaptureSessionLocalDataSource _sessionLocal;
  final SyncRemoteDataSource _remote;
  final DeviceIdProvider _deviceIdProvider;
  final DirectoryManager _directoryManager;

  Future<void> drainAll() async {
    final pending = _queueLocal.all().where(
      (i) => i.status == 'queued' || i.status == 'uploading',
    );
    for (final item in pending) {
      await _drainOne(item);
    }
  }

  Future<void> drainOne(String id) async {
    final item = _queueLocal.get(id);
    if (item != null) await _drainOne(item);
  }

  Future<void> _drainOne(SyncQueueItemRecord item) async {
    final session = _sessionLocal.get(item.wallId);
    if (session == null) {
      item.status = 'failed';
      item.lastError = 'No local capture data found for this wall.';
      await _queueLocal.put(item);
      return;
    }

    item.status = 'uploading';
    item.progress = 5;
    await _queueLocal.put(item);

    try {
      final deviceId = await _deviceIdProvider.getOrCreateDeviceId();

      final serverSessionId = await _remote.registerSession(
        deviceId: deviceId,
        siteId: item.siteId,
        wallId: item.wallId,
        session: session,
      );
      session.serverSessionId = serverSessionId;
      await _sessionLocal.put(session);
      item.progress = 20;
      await _queueLocal.put(item);

      final photos = [
        for (final cell in session.cells)
          for (final photo in cell.photos) (cell: cell, photo: photo),
      ];
      for (var i = 0; i < photos.length; i++) {
        final entry = photos[i];
        await _remote.uploadCellPhoto(
          wallId: item.wallId,
          row: entry.cell.row,
          col: entry.cell.col,
          shot: entry.photo.shot,
          filePath: entry.photo.file,
        );
        item.progress = 20 + (((i + 1) / photos.length) * 70).round();
        await _queueLocal.put(item);
      }

      await _remote.confirmSession(serverSessionId);
      item.status = 'confirmed';
      item.progress = 100;
      item.lastError = null;
      await _queueLocal.put(item);

      await _directoryManager.deleteBackup(item.wallId);
    } on AppException catch (e) {
      item.attempts += 1;
      item.lastError = e.failure.message;
      item.status = e.failure is ValidationFailure ? 'failed' : 'queued';
      await _queueLocal.put(item);
    } catch (e) {
      item.attempts += 1;
      item.lastError = e.toString();
      item.status = 'queued';
      await _queueLocal.put(item);
    }
  }
}
