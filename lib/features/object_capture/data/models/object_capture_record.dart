import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'object_capture_record.g.dart';

/// One photograph of an object: a named side (organised capture) or a
/// commented shot (free capture) — never both.
@HiveType(typeId: HiveTypeIds.objectPhotoRecord)
class ObjectPhotoRecord {
  ObjectPhotoRecord({
    required this.file,
    required this.sha256,
    required this.capturedAt,
    this.side,
    this.comment,
    this.uploaded = false,
  });

  @HiveField(0)
  final String file;

  @HiveField(1)
  final String sha256;

  @HiveField(2)
  final DateTime capturedAt;

  /// An `ObjectSide` name, or null for a free photograph.
  @HiveField(3)
  final String? side;

  @HiveField(4)
  final String? comment;

  /// The server has this exact file. Lets an interrupted upload resume
  /// where it stopped instead of sending every photo again.
  @HiveField(5, defaultValue: false)
  final bool uploaded;

  ObjectPhotoRecord copyWith({String? comment, bool? uploaded}) {
    return ObjectPhotoRecord(
      file: file,
      sha256: sha256,
      capturedAt: capturedAt,
      side: side,
      comment: comment ?? this.comment,
      uploaded: uploaded ?? this.uploaded,
    );
  }
}

/// Every photograph this phone holds of one object — box `object_captures`,
/// keyed by [wallId], the id this phone knows the object by.
@HiveType(typeId: HiveTypeIds.objectCaptureRecord)
class ObjectCaptureRecord extends HiveObject {
  ObjectCaptureRecord({
    required this.wallId,
    required this.floorId,
    required this.siteId,
    required this.photos,
    required this.createdAt,
  });

  @HiveField(0)
  final String wallId;

  @HiveField(1)
  final String floorId;

  @HiveField(2)
  String siteId;

  @HiveField(3)
  List<ObjectPhotoRecord> photos;

  @HiveField(4)
  final DateTime createdAt;
}
