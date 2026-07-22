import 'dart:async';

import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_queue_repository.dart';

/// In-memory stand-in for the real upload-queue repository, seeded with the
/// exact mock data from the Claude Design handoff prototype
/// (`design-system-documentation/project/WallBase Sites.dc.html`). Mirrors
/// the prototype's `setInterval` simulation: every uploading item advances by
/// 8% every 500ms until it flips to `confirmed`.
class FakeSyncQueueRepository implements SyncQueueRepository {
  FakeSyncQueueRepository() {
    _items = _seed();
    _controller = StreamController<List<SyncItem>>.broadcast();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  static const _progressStep = 8;

  late List<SyncItem> _items;
  late final StreamController<List<SyncItem>> _controller;
  late final Timer _ticker;

  @override
  Stream<List<SyncItem>> watchQueue() async* {
    yield _items;
    yield* _controller.stream;
  }

  @override
  void retry(String id) {
    _items = _items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(status: SyncItemStatus.uploading, progress: 10);
    }).toList();
    _controller.add(_items);
  }

  void _tick() {
    var changed = false;
    _items = _items.map((item) {
      if (item.status != SyncItemStatus.uploading) return item;
      changed = true;
      final next = item.progress + _progressStep;
      if (next >= 100) {
        return item.copyWith(status: SyncItemStatus.confirmed, progress: 100);
      }
      return item.copyWith(progress: next);
    }).toList();
    if (changed) _controller.add(_items);
  }

  void dispose() {
    _ticker.cancel();
    _controller.close();
  }

  List<SyncItem> _seed() => const [
    SyncItem(
      id: 'sy1',
      name: 'Mastaba A · East face',
      status: SyncItemStatus.uploading,
      progress: 55,
    ),
    SyncItem(
      id: 'sy2',
      name: 'Mastaba A · West face',
      status: SyncItemStatus.queued,
    ),
    SyncItem(
      id: 'sy3',
      name: 'Causeway · Segment 1',
      status: SyncItemStatus.confirmed,
      progress: 100,
    ),
    SyncItem(
      id: 'sy4',
      name: 'Hypostyle Hall · Column row A',
      status: SyncItemStatus.failed,
    ),
  ];
}
