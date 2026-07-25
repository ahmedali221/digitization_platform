import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'sync_queue_item_record.g.dart';

/// One capture session's upload lifecycle — box `sync_queue`
/// (FLUTTER_MOBILE_PLAN.md §3), keyed by [id]. [siteId] lets a future
/// "delete cached site" flow check for unsynced sessions before allowing
/// deletion.
@HiveType(typeId: HiveTypeIds.syncQueueItemRecord)
class SyncQueueItemRecord extends HiveObject {
  SyncQueueItemRecord({
    required this.id,
    required this.sessionId,
    required this.wallId,
    required this.siteId,
    required this.displayName,
    required this.status,
    this.progress = 0,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final String wallId;

  @HiveField(3)
  final String siteId;

  @HiveField(4)
  final String displayName;

  /// 'queued' | 'uploading' | 'confirmed' | 'failed'.
  @HiveField(5)
  String status;

  @HiveField(6)
  int progress;

  @HiveField(7)
  int attempts;

  @HiveField(8)
  String? lastError;

  @HiveField(9)
  final DateTime createdAt;
}
