/// Which OpenCV transform [CaptureAnalyzer] fits between a cell and a
/// neighbour — mirrors stitch.py's `--transform` flag exactly (same two
/// choices, same tradeoff: affine can't runaway-scale, homography handles
/// real parallax at a seam).
enum TransformModel { homography, affine }

/// How a cell's several [NeighbourMatchMetrics] collapse into one
/// `neighbour_score`. The spec (§3) suggests trying both during calibration.
enum NeighbourCombineMode { average, worstCase }

/// Every threshold and weight [CaptureAnalyzer] uses, gathered in one place
/// so none of it is a constant baked into the scoring code — per the spec's
/// explicit rule ("every threshold is a config value ... because the right
/// cut-offs can only be found by testing on real device captures").
///
/// Where stitch.py already tunes the same knob (SIFT params, Lowe ratio,
/// RANSAC threshold, direction/scale checks), the default here matches it
/// exactly, so an on-device Tier 1-3 score stays numerically consistent with
/// what the backend's own `--audit` would measure for the same photos.
///
/// The Tier 1/2/3 weightings and the normalization "full score" anchors
/// below are this spec's own starting points (§3, §9) — they have not yet
/// been calibrated against real device captures, and are expected to move
/// once that measurement pass happens.
class CaptureQualityConfig {
  const CaptureQualityConfig({
    // -- Tier 1: SIFT (cv2.SIFT_create() parity — spec: "no custom params,
    // consistency matters more than tuning this in isolation") --
    this.siftFeatures = 0,
    this.siftOctaveLayers = 3,
    this.siftContrastThreshold = 0.04,
    this.siftEdgeThreshold = 10,
    this.siftSigma = 1.6,

    // -- Tier 1: spatial distribution + edge strip --
    this.spatialGridSize = 4,
    this.edgeStripFraction = 0.30,

    // -- Tier 1: normalization anchors (metric value that saturates the
    // normalized term at 1.0; 0 maps to 0.0, linear/clamped between) --
    this.keypointDensityFullScore = 500, // keypoints per megapixel
    this.edgeDensityFullScore = 500, // relevant-edge keypoints per megapixel
    this.sharpnessFullScore = 500, // Laplacian variance
    this.contrastFullScore = 60, // grayscale std dev, 0-255

    // -- Tier 1 weights (spec §3, sum to 1.0) --
    this.weightKeypointDensity = 0.35,
    this.weightSpatialDistribution = 0.20,
    this.weightRelevantEdgeDensity = 0.20,
    this.weightSharpness = 0.15,
    this.weightContrast = 0.10,

    // -- Tier 2/3: matching + RANSAC (same defaults as stitch.py's
    // Stitcher/--ratio/--min-matches/--ransac-thresh/--dir-dominance/
    // --min-scale/--max-scale) --
    this.loweRatio = 0.75,
    this.minGoodMatches = 10,
    this.transformModel = TransformModel.homography,
    this.ransacReprojThreshold = 5.0,
    this.dirDominance = 1.0,
    this.minScale = 0.5,
    this.maxScale = 2.0,

    // -- Tier 2/3 normalization anchors --
    this.goodMatchesFullScore = 80,
    this.ransacInliersFullScore = 60,

    // -- Tier 3 weights (spec §3, sum to 1.0) --
    this.weightGoodMatchScore = 0.25,
    this.weightRansacInlierScore = 0.35,
    this.weightInlierRatio = 0.20,
    this.weightDirectionScore = 0.10,
    this.weightScaleAndOverlapScore = 0.10,

    this.neighbourCombineMode = NeighbourCombineMode.average,

    // -- Combined cell score (spec §3) --
    this.weightImageScore = 0.40,
    this.weightNeighbourScore = 0.60,

    // -- Heat color bands (spec §5) --
    this.redMaxScore = 39,
    this.orangeMaxScore = 59,
    this.yellowMaxScore = 79,
  });

  final int siftFeatures;
  final int siftOctaveLayers;
  final double siftContrastThreshold;
  final double siftEdgeThreshold;
  final double siftSigma;

  final int spatialGridSize;
  final double edgeStripFraction;

  final double keypointDensityFullScore;
  final double edgeDensityFullScore;
  final double sharpnessFullScore;
  final double contrastFullScore;

  final double weightKeypointDensity;
  final double weightSpatialDistribution;
  final double weightRelevantEdgeDensity;
  final double weightSharpness;
  final double weightContrast;

  final double loweRatio;
  final int minGoodMatches;
  final TransformModel transformModel;
  final double ransacReprojThreshold;
  final double dirDominance;
  final double minScale;
  final double maxScale;

  final double goodMatchesFullScore;
  final double ransacInliersFullScore;

  final double weightGoodMatchScore;
  final double weightRansacInlierScore;
  final double weightInlierRatio;
  final double weightDirectionScore;
  final double weightScaleAndOverlapScore;

  final NeighbourCombineMode neighbourCombineMode;

  final double weightImageScore;
  final double weightNeighbourScore;

  final double redMaxScore;
  final double orangeMaxScore;
  final double yellowMaxScore;
}
