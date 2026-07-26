import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../models/capture_session_record.dart';

/// Pure Hive CRUD over the `sessions` box — no file I/O (that's
/// [GridCaptureLocalDataSource]), no wall/status logic (that's
/// [GridCaptureRepository]).
class CaptureSessionLocalDataSource {
  Box<CaptureSessionRecord> get _box =>
      Hive.box<CaptureSessionRecord>(HiveBoxes.sessions);

  CaptureSessionRecord? get(String wallId) => _box.get(wallId);

  Future<void> put(CaptureSessionRecord record) =>
      _box.put(record.wallId, record);

  Stream<void> watch(String wallId) => _box.watch(key: wallId);
}
