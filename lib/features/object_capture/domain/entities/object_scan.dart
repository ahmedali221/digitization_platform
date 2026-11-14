import 'package:equatable/equatable.dart';

import 'scan_coverage.dart';
import 'scan_plan.dart';
import 'scan_preview.dart';

/// One photograph of a 3D scan and the slice of the plan it was taken for.
class ScanShot extends Equatable {
  const ScanShot({
    required this.path,
    required this.cell,
    this.isUploaded = false,
  });

  final String path;
  final ScanCell cell;
  final bool isUploaded;

  @override
  List<Object?> get props => [path, cell, isUploaded];
}

/// Where a scan stands, as the operator needs to know it.
enum ScanStage {
  /// Photographs are still being taken.
  capturing,

  /// Finished on this phone; photographs are on their way to the server.
  uploading,

  /// The server is working out whether the photographs cover the object.
  checking,
  needsMorePhotos,

  /// The photographs were enough and the model is being built.
  buildingModel,
  modelReady,
  failed,
  cancelled,
}

/// What the server last said about a scan.
class ScanServerState extends Equatable {
  const ScanServerState({
    required this.status,
    this.reasons = const [],
    this.gaps = const [],
    this.failureReason,
    this.runProgress = 0,
    this.preview,
  });

  /// The dashboard's own status name (`ScanStatus` there).
  final String status;

  /// Why more photographs are needed, in the server's words.
  final List<String> reasons;
  final List<CoverageGap> gaps;
  final String? failureReason;

  /// How far the server's current step is, from 0 to 1.
  final double runProgress;

  /// The rough model of the scan as it stands, if the server is making one.
  final ScanPreview? preview;

  @override
  List<Object?> get props => [
    status,
    reasons,
    gaps,
    failureReason,
    runProgress,
    preview,
  ];
}

/// The 3D scan this phone holds of one object: its photographs, whether the
/// operator has finished shooting, and what the server made of them.
class ObjectScan extends Equatable {
  const ObjectScan({
    this.shots = const [],
    this.isFinished = false,
    this.isConfirmed = false,
    this.server,
    this.cellsToRetake = const {},
  });

  final List<ScanShot> shots;

  /// Slices to photograph again although a photograph of them is held: the
  /// rough model has a hole there. The held photograph stays in the scan.
  final Set<ScanCell> cellsToRetake;

  /// The operator has stopped shooting and handed the scan over.
  final bool isFinished;

  /// The server holds every photograph this phone took.
  final bool isConfirmed;
  final ScanServerState? server;

  ScanCoverage get coverage => ScanCoverage({
    for (final shot in shots)
      if (!cellsToRetake.contains(shot.cell)) shot.cell,
  });

  /// The slices the operator can go back for: those facing the holes in the
  /// rough model.
  Set<ScanCell> get missingParts => server?.preview?.missingCells ?? const {};

  int get uploadedCount => shots.where((shot) => shot.isUploaded).length;

  ScanStage get stage {
    if (!isFinished) return ScanStage.capturing;
    if (!isConfirmed) return ScanStage.uploading;
    return switch (server?.status) {
      'needs_more_photos' => ScanStage.needsMorePhotos,
      'processing' => ScanStage.buildingModel,
      'completed' => ScanStage.modelReady,
      'failed' => ScanStage.failed,
      'cancelled' => ScanStage.cancelled,
      _ => ScanStage.checking,
    };
  }

  /// Nothing more will change without the operator doing something.
  bool get isSettled => switch (stage) {
    ScanStage.capturing => true,
    ScanStage.needsMorePhotos ||
    ScanStage.modelReady ||
    ScanStage.failed ||
    ScanStage.cancelled => server?.preview?.isSettled ?? true,
    ScanStage.uploading ||
    ScanStage.checking ||
    ScanStage.buildingModel => false,
  };

  @override
  List<Object?> get props => [
    shots,
    isFinished,
    isConfirmed,
    server,
    cellsToRetake,
  ];
}
