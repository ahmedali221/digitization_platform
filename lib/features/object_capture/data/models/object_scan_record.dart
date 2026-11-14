import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'object_scan_record.g.dart';

/// One photograph of a 3D scan and the slice of the plan it was taken for.
@HiveType(typeId: HiveTypeIds.scanShotRecord)
class ScanShotRecord {
  ScanShotRecord({
    required this.file,
    required this.sha256,
    required this.capturedAt,
    required this.ring,
    required this.sector,
    this.uploaded = false,
    this.serverSequence,
  });

  @HiveField(0)
  final String file;

  @HiveField(1)
  final String sha256;

  @HiveField(2)
  final DateTime capturedAt;

  @HiveField(3)
  final int ring;

  @HiveField(4)
  final int sector;

  /// The server has this exact file, so an interrupted upload resumes with
  /// the photographs still to go.
  @HiveField(5, defaultValue: false)
  final bool uploaded;

  /// The number the server gave this photograph. Its coverage report names
  /// the photographs it could not use by this number.
  @HiveField(6)
  final int? serverSequence;

  ScanShotRecord asUploaded(int serverSequence) => ScanShotRecord(
    file: file,
    sha256: sha256,
    capturedAt: capturedAt,
    ring: ring,
    sector: sector,
    uploaded: true,
    serverSequence: serverSequence,
  );
}

/// The 3D scan this phone holds of one object: box `object_scans`, keyed by
/// [wallId], the id this phone knows the object by.
@HiveType(typeId: HiveTypeIds.objectScanRecord)
class ObjectScanRecord extends HiveObject {
  ObjectScanRecord({
    required this.wallId,
    required this.floorId,
    required this.siteId,
    required this.clientUuid,
    required this.shots,
    required this.createdAt,
    this.isFinished = false,
    this.fullCircle = true,
    this.isConfirmed = false,
    this.serverScanId,
    this.serverStatus,
    this.serverReasons = const [],
    this.serverGaps = const [],
    this.serverUnplaced = const [],
    this.serverFailureReason,
    this.serverRunProgress = 0,
    this.previewId,
    this.previewStatus,
    this.previewProgress = 0,
    this.previewUnseenFraction,
    this.previewMissingCells = const [],
    this.previewModelFile,
    this.cellsToRetake = const [],
  });

  @HiveField(0)
  final String wallId;

  @HiveField(1)
  final String floorId;

  @HiveField(2)
  String siteId;

  /// Minted here, so starting the scan on the server twice is one scan.
  @HiveField(3)
  final String clientUuid;

  @HiveField(4)
  List<ScanShotRecord> shots;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6, defaultValue: false)
  bool isFinished;

  @HiveField(7, defaultValue: true)
  bool fullCircle;

  /// The server answered that it holds every photograph in [shots].
  @HiveField(8, defaultValue: false)
  bool isConfirmed;

  @HiveField(9)
  int? serverScanId;

  @HiveField(10)
  String? serverStatus;

  @HiveField(11, defaultValue: <String>[])
  List<String> serverReasons;

  /// Arcs with no usable photograph, as from/to pairs of degrees.
  @HiveField(12, defaultValue: <double>[])
  List<double> serverGaps;

  @HiveField(13)
  String? serverFailureReason;

  @HiveField(14, defaultValue: 0.0)
  double serverRunProgress;

  /// Server numbers of the photographs the server made nothing of.
  @HiveField(15, defaultValue: <int>[])
  List<int> serverUnplaced;

  /// The server's rough model of the scan (its preview run), by the id the
  /// server knows it by: a new id is a new model to fetch.
  @HiveField(16)
  int? previewId;

  @HiveField(17)
  String? previewStatus;

  @HiveField(18, defaultValue: 0.0)
  double previewProgress;

  @HiveField(19)
  double? previewUnseenFraction;

  /// The slices facing the holes in the rough model, as ring/sector pairs.
  @HiveField(20, defaultValue: <int>[])
  List<int> previewMissingCells;

  /// Where the rough model was saved on this phone.
  @HiveField(21)
  String? previewModelFile;

  /// Slices to photograph again although a photograph of them is held, as
  /// ring/sector pairs: the held one stays in the scan, another is added.
  @HiveField(22, defaultValue: <int>[])
  List<int> cellsToRetake;
}
