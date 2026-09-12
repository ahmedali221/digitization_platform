import '../../domain/entities/capture_quality.dart';
import '../models/cell_quality_record.dart';

/// [CellQualityResult] <-> [CellQualityRecord] — the only place either side
/// of the Capture Quality Indicator's domain/persistence boundary meets, so
/// a field rename on one side only ever breaks one file.
class CellQualityMapper {
  const CellQualityMapper._();

  static CellQualityRecord toRecord(CellQualityResult result) {
    return CellQualityRecord(
      keypointCount: result.image.keypointCount,
      keypointDensity: result.image.keypointDensity,
      spatialDistribution: result.image.spatialDistribution,
      edgeLeft: result.image.edgeKeypoints[EdgeSide.left] ?? 0,
      edgeRight: result.image.edgeKeypoints[EdgeSide.right] ?? 0,
      edgeTop: result.image.edgeKeypoints[EdgeSide.top] ?? 0,
      edgeBottom: result.image.edgeKeypoints[EdgeSide.bottom] ?? 0,
      relevantEdgeDensity: result.image.relevantEdgeDensity,
      sharpness: result.image.sharpness,
      contrast: result.image.contrast,
      imageScore: result.image.imageScore,
      neighbours: result.neighbours.map(_neighbourToRecord).toList(),
      cellScore: result.cellScore,
      status: _tierToString(result.tier),
      failureReason: result.failureReason,
      computedAt: result.computedAt,
    );
  }

  static CellQualityResult toResult(
    int cellIndex,
    CellQualityRecord record, {
    bool overridden = false,
  }) {
    return CellQualityResult(
      cellIndex: cellIndex,
      overridden: overridden,
      image: ImageQualityMetrics(
        keypointCount: record.keypointCount,
        keypointDensity: record.keypointDensity,
        spatialDistribution: record.spatialDistribution,
        edgeKeypoints: {
          EdgeSide.left: record.edgeLeft,
          EdgeSide.right: record.edgeRight,
          EdgeSide.top: record.edgeTop,
          EdgeSide.bottom: record.edgeBottom,
        },
        relevantEdgeDensity: record.relevantEdgeDensity,
        sharpness: record.sharpness,
        contrast: record.contrast,
        imageScore: record.imageScore,
      ),
      neighbours: record.neighbours.map(_neighbourToMetrics).toList(),
      cellScore: record.cellScore,
      tier: _tierFromString(record.status),
      failureReason: record.failureReason,
      computedAt: record.computedAt,
    );
  }

  static NeighbourQualityRecord _neighbourToRecord(NeighbourMatchMetrics m) {
    return NeighbourQualityRecord(
      direction: _directionToString(m.direction),
      neighbourCellIndex: m.neighbourCellIndex,
      goodMatches: m.goodMatches,
      ransacInliers: m.ransacInliers,
      inlierRatio: m.inlierRatio,
      dx: m.dx,
      dy: m.dy,
      scale: m.scale,
      directionOk: m.directionOk,
      scaleOk: m.scaleOk,
      neighbourScore: m.neighbourScore,
    );
  }

  static NeighbourMatchMetrics _neighbourToMetrics(NeighbourQualityRecord r) {
    return NeighbourMatchMetrics(
      direction: _directionFromString(r.direction),
      neighbourCellIndex: r.neighbourCellIndex,
      goodMatches: r.goodMatches,
      ransacInliers: r.ransacInliers,
      inlierRatio: r.inlierRatio,
      dx: r.dx,
      dy: r.dy,
      scale: r.scale,
      directionOk: r.directionOk,
      scaleOk: r.scaleOk,
      neighbourScore: r.neighbourScore,
    );
  }

  static String _tierToString(QualityTier tier) => tier.name;

  static QualityTier _tierFromString(String value) =>
      QualityTier.values.firstWhere((t) => t.name == value, orElse: () => QualityTier.red);

  static String _directionToString(NeighbourDirection direction) => direction.name;

  static NeighbourDirection _directionFromString(String value) => NeighbourDirection.values.firstWhere(
    (d) => d.name == value,
    orElse: () => NeighbourDirection.right,
  );
}
