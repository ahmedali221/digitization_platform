import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';
import '../models/follow_up_upload_record.dart';

class FollowUpLocalDataSource {
  Box<FollowUpUploadRecord> get _box =>
      Hive.box<FollowUpUploadRecord>(HiveBoxes.followUpUploads);

  List<FollowUpUploadRecord> all() => _box.values.toList();

  Future<void> put(FollowUpUploadRecord record) => _box.put(record.token, record);

  Future<void> delete(String token) => _box.delete(token);
}
