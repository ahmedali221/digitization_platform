import 'package:hive/hive.dart';

import '../../../../core/data/models/hive_type_ids.dart';

part 'cell_quality_record.g.dart';

@HiveType(typeId: HiveTypeIds.neighbourQualityRecord)
class NeighbourQualityRecord {
  NeighbourQualityRecord({
    required this.direction,
    required this.neighbourCellIndex,
    required this.goodMatches,
    required this.ransacInliers,
    required this.inlierRatio,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.directionOk,
    required this.scaleOk,
    required this.neighbourScore,
  });

  /// 'left' | 'right' | 'top' | 'bottom'.
  @HiveField(0)
  final String direction;

  @HiveField(1)
  final int neighbourCellIndex;

  @HiveField(2)
  final int goodMatches;

  @HiveField(3)
  final int ransacInliers;

  @HiveField(4)
  final double inlierRatio;

  @HiveField(5)
  final double dx;

  @HiveField(6)
  final double dy;

  @HiveField(7)
  final double scale;

  @HiveField(8)
  final bool directionOk;

  @HiveField(9)
  final bool scaleOk;

  @HiveField(10)
  final double neighbourScore;
}

/// One candidate shot's score — see `ShotQualityScore`'s domain-side doc for
/// why this is kept per-shot rather than only for the winner.
@HiveType(typeId: HiveTypeIds.shotQualityScoreRecord)
class ShotQualityScoreRecord {
  ShotQualityScoreRecord({
    required this.imagePath,
    required this.cellScore,
    required this.status,
  });

  @HiveField(0)
  final String imagePath;

  @HiveField(1)
  final double cellScore;

  /// 'red' | 'orange' | 'yellow' | 'green'.
  @HiveField(2)
  final String status;
}

/// Raw Tier 1-3 metrics for one cell's current shot, persisted alongside the
/// score (Capture Quality Indicator spec §8) so the on-device/backend
/// boundary question (spec §9) can be revisited from real field data later —
/// "without the raw numbers, only the final colour is recoverable".
@HiveType(typeId: HiveTypeIds.cellQualityRecord)
class CellQualityRecord {
  CellQualityRecord({
    required this.keypointCount,
    required this.keypointDensity,
    required this.spatialDistribution,
    required this.edgeLeft,
    required this.edgeRight,
    required this.edgeTop,
    required this.edgeBottom,
    required this.relevantEdgeDensity,
    required this.sharpness,
    required this.contrast,
    required this.imageScore,
    required this.neighbours,
    required this.cellScore,
    required this.status,
    required this.failureReason,
    required this.computedAt,
    this.imagePath,
    this.allShotScores = const [],
  });

  @HiveField(0)
  final int keypointCount;

  @HiveField(1)
  final double keypointDensity;

  @HiveField(2)
  final double spatialDistribution;

  @HiveField(3)
  final int edgeLeft;

  @HiveField(4)
  final int edgeRight;

  @HiveField(5)
  final int edgeTop;

  @HiveField(6)
  final int edgeBottom;

  @HiveField(7)
  final double relevantEdgeDensity;

  @HiveField(8)
  final double sharpness;

  @HiveField(9)
  final double contrast;

  @HiveField(10)
  final double imageScore;

  @HiveField(11)
  final List<NeighbourQualityRecord> neighbours;

  @HiveField(12)
  final double cellScore;

  /// 'red' | 'orange' | 'yellow' | 'green'.
  @HiveField(13)
  final String status;

  @HiveField(14)
  final String? failureReason;

  @HiveField(15)
  final DateTime computedAt;

  /// Which of the cell's shots this result was scored from — null for
  /// records persisted before multi-shot scoring existed, in which case the
  /// cell's first shot is assumed to be the one this record describes.
  @HiveField(16)
  final String? imagePath;

  /// Every shot scored for this cell, [imagePath]'s included — empty for
  /// records persisted before per-shot scoring existed.
  @HiveField(17, defaultValue: [])
  final List<ShotQualityScoreRecord> allShotScores;
}
