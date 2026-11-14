import '../../domain/entities/object_scan.dart';
import '../../domain/entities/scan_coverage.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/entities/scan_preview.dart';
import '../../domain/services/view_alignment.dart';
import '../datasources/object_scan_remote_data_source.dart';
import '../models/object_scan_record.dart';

/// Translates between the stored scan, the server's account of it, and the
/// scan the rest of the app works with.
class ObjectScanMapper {
  const ObjectScanMapper._();

  static ObjectScan? toEntity(ObjectScanRecord? record) {
    if (record == null) return null;
    final status = record.serverStatus;
    return ObjectScan(
      shots: [
        for (final shot in record.shots)
          ScanShot(
            path: shot.file,
            cell: ScanCell(shot.ring, shot.sector),
            isUploaded: shot.uploaded,
          ),
      ],
      isFinished: record.isFinished,
      isConfirmed: record.isConfirmed,
      cellsToRetake: _cellsOf(record.cellsToRetake),
      server: status == null
          ? null
          : ScanServerState(
              status: status,
              reasons: record.serverReasons,
              gaps: gapsOf(record),
              failureReason: record.serverFailureReason,
              runProgress: record.serverRunProgress,
              preview: _previewOf(record),
            ),
    );
  }

  static ScanPreview? _previewOf(ObjectScanRecord record) {
    final status = record.previewStatus;
    if (status == null) return null;
    return ScanPreview(
      stage: switch (status) {
        'queued' => ScanPreviewStage.waiting,
        'running' => ScanPreviewStage.building,
        'completed' => ScanPreviewStage.ready,
        _ => ScanPreviewStage.unavailable,
      },
      progress: record.previewProgress,
      modelPath: record.previewModelFile,
      unseenFraction: record.previewUnseenFraction,
      missingCells: _cellsOf(record.previewMissingCells),
    );
  }

  static Set<ScanCell> _cellsOf(List<int> pairs) => {
    for (var i = 0; i + 1 < pairs.length; i += 2)
      ScanCell(pairs[i], pairs[i + 1]),
  };

  static List<int> pairsOf(Iterable<ScanCell> cells) => [
    for (final cell in cells) ...[cell.ring, cell.sector],
  ];

  /// The slices facing the sides the rough model lacks. The server names
  /// those sides in its own angles; the photographs both it and this phone
  /// know are what the two are lined up by. Empty when they cannot be.
  static Set<ScanCell> _missingCells(
    ObjectScanRecord record,
    RemoteScanPreview preview,
  ) {
    final cellBySequence = {
      for (final shot in record.shots)
        if (shot.serverSequence != null)
          shot.serverSequence!: ScanCell(shot.ring, shot.sector),
    };
    final alignment = ViewAlignment.fit([
      for (final view in preview.views)
        if (cellBySequence[view.sequence] case final cell?)
          (phone: ScanPlan.centreOf(cell), server: view.azimuth),
    ]);
    if (alignment == null) return const {};
    return {
      for (final side in preview.unseen)
        ...alignment.cellsFacing(
          azimuth: side.azimuth,
          elevation: side.elevation,
        ),
    };
  }

  /// The arcs the server found empty, read back from their stored pairs.
  static List<CoverageGap> gapsOf(ObjectScanRecord record) {
    final degrees = record.serverGaps;
    return [
      for (var i = 0; i + 1 < degrees.length; i += 2)
        CoverageGap(fromDegrees: degrees[i], toDegrees: degrees[i + 1]),
    ];
  }

  /// Whether the server could make nothing of [shot]: it lies in an arc the
  /// server found empty, or is one of the photographs it could not fit.
  static bool isUnusable(ObjectScanRecord record, ScanShotRecord shot) {
    final centre = ScanPlan.centreOf(ScanCell(shot.ring, shot.sector));
    return record.serverUnplaced.contains(shot.serverSequence) ||
        gapsOf(record).any((gap) => gap.contains(centre));
  }

  static void applyServerState(ObjectScanRecord record, RemoteScanState state) {
    record
      ..serverScanId = state.id
      ..serverStatus = state.status
      ..serverReasons = state.reasons
      ..serverGaps = [
        for (final gap in state.gaps) ...[gap.from, gap.to],
      ]
      ..serverUnplaced = state.isWholeScanUnusable
          ? record.shots.map((shot) => shot.serverSequence).nonNulls.toList()
          : state.unusable
      ..serverFailureReason = state.failureReason
      ..serverRunProgress = state.runProgress;

    final preview = state.preview;
    // A model fetched for an earlier preview is not the model of this one.
    if (preview?.id != record.previewId) record.previewModelFile = null;
    record
      ..previewId = preview?.id
      ..previewStatus = preview?.status
      ..previewProgress = preview?.progress ?? 0
      ..previewUnseenFraction = preview?.unseenFraction
      ..previewMissingCells = preview == null
          ? const []
          : pairsOf(_missingCells(record, preview));
  }

  static void clearServerState(ObjectScanRecord record) {
    record
      ..serverStatus = null
      ..serverReasons = const []
      ..serverGaps = const []
      ..serverUnplaced = const []
      ..serverFailureReason = null
      ..serverRunProgress = 0
      ..previewId = null
      ..previewStatus = null
      ..previewProgress = 0
      ..previewUnseenFraction = null
      ..previewMissingCells = const []
      ..previewModelFile = null;
  }
}
