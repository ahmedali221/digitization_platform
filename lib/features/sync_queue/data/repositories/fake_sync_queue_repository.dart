import '../../domain/entities/sync_item.dart';
import '../../domain/repositories/sync_queue_repository.dart';

/// Always reports an empty queue — matching how `FakeSiteRepository`/
/// `FakeMapGeometryRepository` stay plain in-memory doubles. Used by
/// `test/widget_test.dart`'s manual DI fixture, which never has a real
/// upload queue for `SyncStatusIcon` (rendered on the sites list header) to
/// read from.
class FakeSyncQueueRepository implements SyncQueueRepository {
  const FakeSyncQueueRepository();

  @override
  Stream<List<SyncItem>> watchQueue() => Stream.value(const []);

  @override
  void retry(String id) {}

  @override
  Future<void> discard(String id) async {}
}
