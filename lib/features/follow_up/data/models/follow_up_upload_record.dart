import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'follow_up_upload_record.g.dart';

/// One follow-up photograph on its way to the dashboard, and what became of it.
/// Box `follow_up_uploads`, keyed by [token], which the server also uses to tell
/// a retried upload from a new one.
@HiveType(typeId: HiveTypeIds.followUpUploadRecord)
class FollowUpUploadRecord extends HiveObject {
  FollowUpUploadRecord({
    required this.token,
    required this.kind,
    required this.siteId,
    required this.packageId,
    required this.itemKey,
    required this.label,
    required this.filePath,
    required this.sha256,
    required this.capturedAt,
    this.videoMatchJson,
    this.warningConfirmed = false,
    this.suggestedCornersJson,
    this.status = statusQueued,
    this.attempts = 0,
    this.lastError,
    this.serverStatus,
    this.grade,
    this.baselineGrade,
    this.reasons = const [],
    this.rejectReason,
    required this.createdAt,
  });

  static const String kindAnnotation = 'annotation';
  static const String kindTarget = 'target';

  static const String statusQueued = 'queued';
  static const String statusUploading = 'uploading';
  static const String statusSent = 'sent';
  static const String statusFailed = 'failed';

  @HiveField(0)
  final String token;

  /// [kindAnnotation] or [kindTarget].
  @HiveField(1)
  final String kind;

  @HiveField(2)
  final String siteId;

  @HiveField(3)
  final int packageId;

  /// The annotation id, or the target's AR key.
  @HiveField(4)
  final String itemKey;

  @HiveField(5)
  final String label;

  @HiveField(6)
  final String filePath;

  @HiveField(7)
  final String sha256;

  @HiveField(8)
  final DateTime capturedAt;

  @HiveField(9)
  final String? videoMatchJson;

  @HiveField(10)
  final bool warningConfirmed;

  @HiveField(11)
  final String? suggestedCornersJson;

  @HiveField(12)
  String status;

  @HiveField(13)
  int attempts;

  @HiveField(14)
  String? lastError;

  /// What the dashboard says became of it, once sent.
  @HiveField(15)
  String? serverStatus;

  @HiveField(16)
  String? grade;

  @HiveField(17)
  String? baselineGrade;

  @HiveField(18)
  List<String> reasons;

  @HiveField(19)
  String? rejectReason;

  @HiveField(20)
  final DateTime createdAt;
}
