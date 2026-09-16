import 'package:equatable/equatable.dart';

/// Capture-quality heat band ("Will this photo stitch?" spec §5) — the one
/// color language shared by the per-cell badge, edge indicators, and the
/// Tier 4 wall-preview overlay, so the operator only has to learn it once.
/// Deliberately Flutter-free (unlike its `Color` mapping — see
/// `QualityTierMeta` in the grid_capture presentation layer): every
/// CaptureAnalyzer type must stay plain Dart so it's directly runnable from
/// a host-side script or a `flutter test`, not just the app itself.
enum QualityTier { red, orange, yellow, green }

/// Bands a 0-100 score per spec §5's table. Boundaries are read from
/// [CaptureQualityConfig] rather than hardcoded here — the spec is explicit
/// that real cut-offs can only be set after testing on real device captures.
QualityTier qualityTierForScore(
  double score, {
  required double redMaxScore,
  required double orangeMaxScore,
  required double yellowMaxScore,
}) {
  if (score <= redMaxScore) return QualityTier.red;
  if (score <= orangeMaxScore) return QualityTier.orange;
  if (score <= yellowMaxScore) return QualityTier.yellow;
  return QualityTier.green;
}

/// One of a cell's up-to-four grid-adjacent sides. Which sides are
/// "relevant" for a given cell is read from its position in the grid (a
/// corner cell only needs 2 of its 4 edges scored) — never guessed.
enum EdgeSide { left, right, top, bottom }

extension EdgeSideX on EdgeSide {
  /// The grid-adjacency direction a neighbour across this edge sits in —
  /// same four values, different semantic role (an edge belongs to THIS
  /// cell's frame; a direction points AT another cell).
  NeighbourDirection get towardsNeighbour => switch (this) {
    EdgeSide.left => NeighbourDirection.left,
    EdgeSide.right => NeighbourDirection.right,
    EdgeSide.top => NeighbourDirection.top,
    EdgeSide.bottom => NeighbourDirection.bottom,
  };
}

enum NeighbourDirection { left, right, top, bottom }

extension NeighbourDirectionX on NeighbourDirection {
  /// The edge of THIS cell a neighbour in this direction sits across —
  /// inverse of [EdgeSideX.towardsNeighbour].
  EdgeSide get edge => switch (this) {
    NeighbourDirection.left => EdgeSide.left,
    NeighbourDirection.right => EdgeSide.right,
    NeighbourDirection.top => EdgeSide.top,
    NeighbourDirection.bottom => EdgeSide.bottom,
  };
}

/// Tier 1 — per-image SIFT score (spec §3), computed the instant a photo is
/// taken, before any neighbour exists.
class ImageQualityMetrics extends Equatable {
  const ImageQualityMetrics({
    required this.keypointCount,
    required this.keypointDensity,
    required this.spatialDistribution,
    required this.edgeKeypoints,
    required this.relevantEdgeDensity,
    required this.sharpness,
    required this.contrast,
    required this.imageScore,
  });

  final int keypointCount;

  /// Keypoints per megapixel — resolution-independent, unlike a raw count.
  final double keypointDensity;

  /// occupied_cells / (gridSize * gridSize) over a spatialGridSize x
  /// spatialGridSize split of the frame.
  final double spatialDistribution;

  /// Keypoint counts in the outer edge-strip fraction, one entry per side
  /// this cell's grid position actually has a neighbour on.
  final Map<EdgeSide, int> edgeKeypoints;

  /// Density (per megapixel of strip area) over only the relevant sides.
  final double relevantEdgeDensity;

  /// cv2.Laplacian(gray, CV_64F).var() — focus/blur.
  final double sharpness;

  /// Grayscale standard deviation, 0-255.
  final double contrast;

  /// 0-100, weighted per CaptureQualityConfig's Tier 1 weights.
  final double imageScore;

  @override
  List<Object?> get props => [
    keypointCount,
    keypointDensity,
    spatialDistribution,
    edgeKeypoints,
    relevantEdgeDensity,
    sharpness,
    contrast,
    imageScore,
  ];
}

/// Tier 2+3 — one neighbour's match/RANSAC result (spec §3), computed once
/// both this cell and that neighbour have a captured photo.
class NeighbourMatchMetrics extends Equatable {
  const NeighbourMatchMetrics({
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

  final NeighbourDirection direction;
  final int neighbourCellIndex;

  /// Lowe-ratio-tested matches — "enough matches exist to attempt a fit",
  /// not yet a quality signal on its own (can be inflated by repetitive
  /// texture).
  final int goodMatches;

  /// RANSAC-filtered inliers — matches that agree on ONE consistent
  /// geometric transform. This is where the real stitchability signal
  /// comes from.
  final int ransacInliers;
  final double inlierRatio;

  /// Measured centre offset from check_direction() — dx/dy of where the
  /// neighbour's centre lands once registered into this cell's frame.
  final double dx;
  final double dy;
  final double scale;
  final bool directionOk;
  final bool scaleOk;

  /// 0-100, weighted per CaptureQualityConfig's Tier 3 weights.
  final double neighbourScore;

  @override
  List<Object?> get props => [
    direction,
    neighbourCellIndex,
    goodMatches,
    ransacInliers,
    inlierRatio,
    dx,
    dy,
    scale,
    directionOk,
    scaleOk,
    neighbourScore,
  ];
}

/// One candidate shot's score, kept alongside the winning [CellQualityResult]
/// so a shot that *wasn't* picked can still show its own score/tier when the
/// operator taps it directly, rather than always showing the winner's.
class ShotQualityScore extends Equatable {
  const ShotQualityScore({
    required this.imagePath,
    required this.cellScore,
    required this.tier,
  });

  final String imagePath;
  final double cellScore;
  final QualityTier tier;

  @override
  List<Object?> get props => [imagePath, cellScore, tier];
}

/// One cell's full capture-quality verdict — the record persisted per spec
/// §8, and what drives the heat badge (spec §5) and failure reason (§6).
class CellQualityResult extends Equatable {
  const CellQualityResult({
    required this.cellIndex,
    required this.imagePath,
    required this.image,
    required this.neighbours,
    required this.cellScore,
    required this.tier,
    required this.failureReason,
    required this.computedAt,
    this.overridden = false,
    this.allShotScores = const [],
  });

  final int cellIndex;

  /// Which of the cell's (possibly several) shots this result was scored
  /// from — the highest-scoring one when more than one was submitted, per
  /// [analyzeCellQuality]. Empty for results persisted before this field
  /// existed; callers should fall back to the cell's first shot in that case.
  final String imagePath;
  final ImageQualityMetrics image;

  /// Every shot [analyzeCellQuality] scored for this cell, [imagePath]
  /// included — lets the operator tap any individual retake and see that
  /// specific photo's own score, not just the winner's. Empty for results
  /// persisted before this field existed.
  final List<ShotQualityScore> allShotScores;

  /// One entry per grid-adjacent cell that already has a photo — up to 4.
  final List<NeighbourMatchMetrics> neighbours;

  /// 40% image + 60% neighbours once any neighbour exists, else image alone
  /// (spec §3's combined cell score).
  final double cellScore;
  final QualityTier tier;

  /// The single lowest-scoring contributing metric's human message (spec
  /// §6), or null when the tier is green and there's nothing to fix.
  final String? failureReason;
  final DateTime computedAt;

  /// True once the operator has explicitly chosen to keep this shot despite
  /// a red/orange score (e.g. the wall is genuinely damaged there, or this
  /// is the best angle physically reachable). Never changes [cellScore]/
  /// [tier]/[failureReason] — the score stays honest; this is a separate,
  /// human decision layered on top. Resets whenever the underlying photo
  /// changes (a new shot deserves a fresh decision), but survives a
  /// neighbour-triggered rescore of this same cell.
  final bool overridden;

  CellQualityResult withOverridden(bool value) => CellQualityResult(
    cellIndex: cellIndex,
    imagePath: imagePath,
    image: image,
    neighbours: neighbours,
    cellScore: cellScore,
    tier: tier,
    failureReason: failureReason,
    computedAt: computedAt,
    overridden: value,
    allShotScores: allShotScores,
  );

  /// This cell's score for [path], whether or not it's the winning shot —
  /// falls back to the overall result when [path] isn't in [allShotScores]
  /// (a result persisted before per-shot scores existed).
  ShotQualityScore scoreFor(String path) {
    for (final shot in allShotScores) {
      if (shot.imagePath == path) return shot;
    }
    return ShotQualityScore(imagePath: path, cellScore: cellScore, tier: tier);
  }

  @override
  List<Object?> get props => [
    cellIndex,
    imagePath,
    image,
    neighbours,
    cellScore,
    tier,
    failureReason,
    overridden,
    computedAt,
    allShotScores,
  ];
}

/// The shot to treat as "the" photo for a cell — the one Tier 1-3 scoring
/// picked as best-of-N ([CellQualityResult.imagePath]) when it's still
/// among the cell's current shots, else the earliest capture (no score yet,
/// or the scored shot was since deleted).
String? representativeShotPath(List<String> shotPaths, CellQualityResult? quality) {
  final scored = quality?.imagePath;
  if (scored != null && scored.isNotEmpty && shotPaths.contains(scored)) {
    return scored;
  }
  return shotPaths.isEmpty ? null : shotPaths.first;
}
