import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../models/sync_queue_item_record.dart';

class SyncQueueLocalDataSource {
  Box<SyncQueueItemRecord> get _box =>
      Hive.box<SyncQueueItemRecord>(HiveBoxes.syncQueue);

  List<SyncQueueItemRecord> all() => _box.values.toList();

  Stream<List<SyncQueueItemRecord>> watchAll() async* {
    yield all();
    yield* _box.watch().map((_) => all());
  }

  SyncQueueItemRecord? get(String id) => _box.get(id);

  Future<void> put(SyncQueueItemRecord record) => _box.put(record.id, record);

  Future<void> delete(String id) => _box.delete(id);
}
