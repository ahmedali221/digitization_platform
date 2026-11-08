import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'follow_up_upload_record.g.dart';

/// One photograph of a grid, in a record's [FollowUpUploadRecord.tilesJson].
/// Row and column count from zero, as the dashboard's do.
class GridTile {
  const GridTile({
    required this.row,
    required this.col,
    required this.path,
    required this.sha256,
    this.sent = false,
  });

  factory GridTile.fromJson(Map<String, dynamic> json) => GridTile(
    row: json['row'] as int,
    col: json['col'] as int,
    path: json['path'] as String,
    sha256: json['sha256'] as String,
    sent: json['sent'] as bool? ?? false,
  );

  final int row;
  final int col;
  final String path;
  final String sha256;

  /// The dashboard has it and checked its hash, so the file here can go.
  final bool sent;

  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'path': path,
    'sha256': sha256,
    'sent': sent,
  };
}

/// One follow-up photograph, grid of photographs or target width on its way to
/// the dashboard, and what became of it.
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
    this.physicalWidthM,
    this.widthSource,
    this.previewPath,
    this.rows,
    this.cols,
    this.tilesJson,
    this.failedCellsJson,
    this.description,
  });

  static const String kindAnnotation = 'annotation';
  static const String kindTarget = 'target';

  /// A target's width with no new photograph: [filePath] and [sha256] are empty.
  static const String kindWidth = 'width';

  /// An annotation photographed as a grid, which the dashboard stitches. One
  /// record for the whole grid: [filePath] and [sha256] are empty, see [tiles].
  static const String kindAnnotationGrid = 'annotation_grid';

  /// A target the site had no profile for, photographed to become one in the
  /// studio. [itemKey] and [label] are the code the operator typed, which no
  /// other target of the landmark may share, and [description] says what it is.
  static const String kindNewTarget = 'new_target';

  static const String statusQueued = 'queued';
  static const String statusUploading = 'uploading';
  static const String statusSent = 'sent';
  static const String statusFailed = 'failed';

  @HiveField(0)
  final String token;

  /// [kindAnnotation], [kindAnnotationGrid], [kindTarget], [kindWidth] or
  /// [kindNewTarget].
  @HiveField(1)
  final String kind;

  @HiveField(2)
  final String siteId;

  @HiveField(3)
  final int packageId;

  /// The annotation id, the target's AR key for a target or width, or the
  /// typed code of a new target.
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

  /// How wide the target is, in metres. Null on an annotation.
  @HiveField(21)
  final double? physicalWidthM;

  /// `ar`, `manual` or `existing`. See TargetWidth.
  @HiveField(22)
  final String? widthSource;

  /// A small copy kept to show on the follow-up pages, because [filePath] is
  /// deleted once nothing more can happen to the photograph. Null on a width. On
  /// a grid, a montage of its photographs until the stitched picture arrives.
  @HiveField(23)
  String? previewPath;

  /// A grid's size. Null on everything else.
  @HiveField(24)
  final int? rows;

  @HiveField(25)
  final int? cols;

  /// A grid's photographs: see [tiles].
  @HiveField(26)
  String? tilesJson;

  /// The cells the dashboard couldn't join: see [failedCells].
  @HiveField(27)
  String? failedCellsJson;

  /// What a new target shows, for the studio's profile. Null on everything else.
  @HiveField(28)
  final String? description;

  bool get isNewTarget => kind == kindNewTarget;

  /// A newer upload of the same thing makes an unsent one pointless, except for
  /// target photographs, where the reviewer chooses between all of them.
  bool get replacedByNewerOne => kind != kindTarget;

  bool get isGrid => kind == kindAnnotationGrid;

  /// What this is a photograph of, however it was taken: a grid and a single
  /// photograph of an annotation are two ways of doing the same job.
  String get family => isGrid ? kindAnnotation : kind;

  List<GridTile> get tiles => tilesJson == null
      ? const []
      : [
          for (final tile in jsonDecode(tilesJson!) as List)
            GridTile.fromJson(tile as Map<String, dynamic>),
        ];

  set tiles(List<GridTile> value) =>
      tilesJson = jsonEncode([for (final tile in value) tile.toJson()]);

  List<({int row, int col})> get failedCells => failedCellsJson == null
      ? const []
      : [
          for (final cell in (jsonDecode(failedCellsJson!) as List).cast<Map<String, dynamic>>())
            (row: cell['row'] as int, col: cell['col'] as int),
        ];

  /// The stitched picture has arrived, in place of the montage.
  bool get hasStitchedPreview => previewPath?.endsWith(stitchedPreviewSuffix) ?? false;

  static const String stitchedPreviewSuffix = '_stitched.jpg';
}
