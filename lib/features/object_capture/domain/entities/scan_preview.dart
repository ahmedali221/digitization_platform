import 'package:equatable/equatable.dart';

import 'scan_plan.dart';

/// How far the rough model of a scan has got.
enum ScanPreviewStage {
  /// Waiting for a processing machine to take it.
  waiting,
  building,
  ready,

  /// It could not be built, or was withdrawn. The scan itself is no worse
  /// off: the preview only ever shows, it decides nothing.
  unavailable,
}

/// The rough 3D model the server builds from a scan's photographs within
/// minutes, so the operator sees what is missing while still at the object.
class ScanPreview extends Equatable {
  const ScanPreview({
    required this.stage,
    this.progress = 0,
    this.modelPath,
    this.unseenFraction,
    this.missingCells = const {},
  });

  final ScanPreviewStage stage;

  /// How far the build is, from 0 to 1.
  final double progress;

  /// The model's file on this phone, once it has been fetched.
  final String? modelPath;

  /// The share of the model's surface that is holes, from 0 to 1. A whole
  /// side nobody photographed is not counted here: the server's check of
  /// the coverage reports that.
  final double? unseenFraction;

  /// The photographs of the plan that face those holes.
  final Set<ScanCell> missingCells;

  bool get canBeShown => stage == ScanPreviewStage.ready && modelPath != null;

  /// Nothing more will come of it by waiting.
  bool get isSettled => canBeShown || stage == ScanPreviewStage.unavailable;

  @override
  List<Object?> get props => [
    stage,
    progress,
    modelPath,
    unseenFraction,
    missingCells,
  ];
}
