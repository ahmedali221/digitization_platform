import 'package:equatable/equatable.dart';

import '../../domain/entities/scan_coverage.dart';
import '../../domain/services/auto_shutter.dart';

enum ScanCapturePhase {
  preparing,

  /// A new scan, waiting for the operator to frame the object and start.
  ready,

  /// A scan with photographs is being continued: the operator must stand
  /// where it began before the app can tell one side from another again.
  aligning,
  scanning,

  /// Handed over for upload; the screen moves on to the scan's status.
  finished,
  noSensors,
  objectMissing,
}

/// What the scan screen shows: where the scan stands and what the operator
/// should do this moment.
class ScanCaptureState extends Equatable {
  const ScanCaptureState({
    this.phase = ScanCapturePhase.preparing,
    this.objectName = '',
    this.coverage = const ScanCoverage(),
    this.guidance = ScanGuidance.holdStill,
    this.azimuth = 0,
    this.shotRequest = 0,
    this.failure,
  });

  final ScanCapturePhase phase;
  final String objectName;
  final ScanCoverage coverage;
  final ScanGuidance guidance;

  /// Whole degrees round the object from the scan's first photograph.
  final int azimuth;

  /// Goes up by one each time a photograph is due: the screen, which owns
  /// the camera, takes one whenever this changes.
  final int shotRequest;

  /// Why the last photograph was not kept, to be shown once.
  final String? failure;

  ScanCaptureState copyWith({
    ScanCapturePhase? phase,
    String? objectName,
    ScanCoverage? coverage,
    ScanGuidance? guidance,
    int? azimuth,
    int? shotRequest,
    String? failure,
  }) {
    return ScanCaptureState(
      phase: phase ?? this.phase,
      objectName: objectName ?? this.objectName,
      coverage: coverage ?? this.coverage,
      guidance: guidance ?? this.guidance,
      azimuth: azimuth ?? this.azimuth,
      shotRequest: shotRequest ?? this.shotRequest,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    objectName,
    coverage,
    guidance,
    azimuth,
    shotRequest,
    failure,
  ];
}
