import '../../../../core/errors/failure.dart';
import '../../data/datasources/sync_queue_local_data_source.dart';
import '../../data/models/sync_queue_item_record.dart';
import '../entities/sync_item_kind.dart';
import 'capture_uploader.dart';
import 'field_item_registrar.dart';

/// Drains the sync queue. For each item: make sure the server knows the
/// wall (`FieldItemRegistrar`), hand the photos to the uploader for the
/// item's kind, and delete the local backup copies only once that uploader
/// reports the server has confirmed them (Invariant 1).
///
/// Network/5xx failures stay `queued` so the next drain (manual "Sync now"
/// or the background task) retries automatically; a 422 validation failure
/// is terminal (`failed`) and needs the operator to fix the capture before a
/// manual retry, per the contract's documented guidance — never
/// blind-retried.
class SyncQueueRunner {
  SyncQueueRunner({
    required SyncQueueLocalDataSource queueLocal,
    required FieldItemRegistrar registrar,
    required Map<SyncItemKind, CaptureUploader> uploaders,
  }) : _queueLocal = queueLocal,
       _registrar = registrar,
       _uploaders = uploaders;

  /// Where the bar stands once the server knows the wall, before any photo.
  static const _startedPercent = 5;
  static const _rejectedMessage =
      'This item was rejected on the dashboard, so its photos were not sent.';
  static const _nothingToSendMessage =
      'No local capture data found for this item.';

  final SyncQueueLocalDataSource _queueLocal;
  final FieldItemRegistrar _registrar;
  final Map<SyncItemKind, CaptureUploader> _uploaders;

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
    final uploader = _uploaders[item.kind]!;
    if (!uploader.hasCapture(item.wallId)) {
      await _fail(item, _nothingToSendMessage);
      return;
    }

    item
      ..status = 'uploading'
      ..progress = _startedPercent;
    await _queueLocal.put(item);

    try {
      final wall = await _registrar.serverWallFor(item.wallId);
      if (wall.isArchived) {
        await _fail(item, _rejectedMessage);
        return;
      }

      await uploader.upload(
        localWallId: item.wallId,
        serverWallId: wall.serverWallId,
        siteId: item.siteId,
        onProgress: (fraction) => _reportProgress(item, fraction),
      );

      item
        ..status = 'confirmed'
        ..progress = 100
        ..lastError = null;
      await _queueLocal.put(item);

      await uploader.deleteBackups(
        localWallId: item.wallId,
        siteId: item.siteId,
      );
    } on AppException catch (e) {
      item
        ..attempts += 1
        ..lastError = e.failure.message
        ..status = e.failure is ValidationFailure ? 'failed' : 'queued';
      await _queueLocal.put(item);
    } catch (e) {
      item
        ..attempts += 1
        ..lastError = e.toString()
        ..status = 'queued';
      await _queueLocal.put(item);
    }
  }

  void _reportProgress(SyncQueueItemRecord item, double fraction) {
    item.progress =
        _startedPercent + (fraction * (100 - _startedPercent)).round();
    _queueLocal.put(item);
  }

  Future<void> _fail(SyncQueueItemRecord item, String message) {
    item
      ..status = 'failed'
      ..lastError = message;
    return _queueLocal.put(item);
  }
}
