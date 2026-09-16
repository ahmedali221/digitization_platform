import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../entities/capture_quality.dart';
import 'capture_quality_config.dart';

/// One grid-adjacent cell that already has a captured photo, fed into
/// [analyzeCellQuality] alongside the cell being scored.
class NeighbourImageInput {
  const NeighbourImageInput({
    required this.direction,
    required this.cellIndex,
    required this.imagePath,
  });

  final NeighbourDirection direction;
  final int cellIndex;
  final String imagePath;
}

/// Plain-data request for [analyzeCellQuality] — must stay free of any
/// native handle (Mat, VecKeyPoint, ...) so it can cross the `compute()`
/// isolate boundary the caller dispatches this through (see
/// CaptureSessionCubit). [relevantEdges] is read from the grid, not
/// guessed — a corner cell only needs 2 of its 4 edges scored.
class CellQualityRequest {
  const CellQualityRequest({
    required this.cellIndex,
    required this.imagePaths,
    required this.relevantEdges,
    this.neighbours = const [],
    this.config = const CaptureQualityConfig(),
  });

  final int cellIndex;

  /// Every shot captured for this cell so far — never empty. Each is scored
  /// independently against [neighbours] and the highest-scoring one wins
  /// (see [analyzeCellQuality]), so a cell with a bad first attempt and a
  /// good retake isn't penalized for keeping both.
  final List<String> imagePaths;
  final Set<EdgeSide> relevantEdges;
  final List<NeighbourImageInput> neighbours;
  final CaptureQualityConfig config;
}

/// Runs Tier 1 (always) and Tier 2/3 (for every neighbour already
/// captured), entirely inside whichever isolate the caller runs it in —
/// this function itself has no Flutter dependency, so it's also directly
/// reusable from a host-side (non-Flutter) validation script.
///
/// Mirrors stitch.py's `Stitcher` (features/match_points/fit_transform/
/// check_direction) using the same underlying OpenCV core via opencv_dart,
/// so a mobile score stays numerically consistent with what the backend's
/// own `--audit` would measure for the same photos — this is the single
/// implementation the spec's "don't build a second SIFT system" rule asks
/// for, not a second one that happens to agree today.
CellQualityResult analyzeCellQuality(CellQualityRequest request) {
  final config = request.config;
  final sift = cv.SIFT.create(
    nfeatures: config.siftFeatures,
    nOctaveLayers: config.siftOctaveLayers,
    contrastThreshold: config.siftContrastThreshold,
    edgeThreshold: config.siftEdgeThreshold,
    sigma: config.siftSigma,
    // Explicit, not just SIFT's own default: SIFT.create() routes to a
    // different native symbol depending on whether this is null
    // (cv_SIFT_create_2) or set (cv_SIFT_create_1); CV_32F is SIFT's real
    // descriptor type either way, so this changes nothing about the
    // detector itself, but avoids relying on the overload actually used
    // upstream matching between platforms.
    descriptorType: cv.MatType.CV_32F,
  );
  final matcher = cv.BFMatcher.create();
  final disposables = <void Function()>[sift.dispose, matcher.dispose];
  final featureCache = <String, _ImageFeatures>{};

  try {
    _ImageFeatures featuresFor(String path) {
      final cached = featureCache[path];
      if (cached != null) return cached;

      final img = cv.imread(path);
      disposables.add(img.dispose);
      if (img.rows == 0 || img.cols == 0) {
        throw StateError('capture_analyzer: unreadable image at $path');
      }
      final gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
      disposables.add(gray.dispose);

      final (keypoints, descriptors) = sift.detectAndCompute(gray, cv.Mat.empty());
      disposables.add(keypoints.dispose);
      disposables.add(descriptors.dispose);

      final laplacian = cv.laplacian(gray, cv.MatType.CV_64F);
      final sharpness = laplacian.variance().val1;
      laplacian.dispose();
      final (mean, stddev) = cv.meanStdDev(gray);
      final contrast = stddev.val1;
      mean.dispose();
      stddev.dispose();

      final features = _ImageFeatures(
        keypoints: keypoints,
        descriptors: descriptors,
        width: img.cols,
        height: img.rows,
        sharpness: sharpness,
        contrast: contrast,
      );
      featureCache[path] = features;
      return features;
    }

    if (request.imagePaths.isEmpty) {
      throw StateError(
        'capture_analyzer: no images to score for cell ${request.cellIndex}',
      );
    }

    // Score every shot taken for this cell independently and keep whichever
    // scores highest — a cell with a weak first attempt and a strong retake
    // must be judged (and later stitched/previewed) by the retake, not
    // whichever photo happened to land first. Every candidate's score is
    // kept in `allShotScores` too, so a shot that *wasn't* picked can still
    // show its own score when the operator taps it directly.
    CellQualityResult? best;
    final allShotScores = <ShotQualityScore>[];
    for (final candidatePath in request.imagePaths) {
      final self = featuresFor(candidatePath);
      final image = _scoreImage(self, request.relevantEdges, config);

      final neighbours = <NeighbourMatchMetrics>[];
      for (final n in request.neighbours) {
        final neighbourFeatures = featuresFor(n.imagePath);
        neighbours.add(
          _scoreNeighbour(
            matcher: matcher,
            self: self,
            neighbour: neighbourFeatures,
            direction: n.direction,
            neighbourCellIndex: n.cellIndex,
            config: config,
          ),
        );
      }

      final cellScore = _combineCellScore(image, neighbours, config);
      final tier = qualityTierForScore(
        cellScore,
        redMaxScore: config.redMaxScore,
        orangeMaxScore: config.orangeMaxScore,
        yellowMaxScore: config.yellowMaxScore,
      );
      allShotScores.add(
        ShotQualityScore(imagePath: candidatePath, cellScore: cellScore, tier: tier),
      );

      final candidate = CellQualityResult(
        cellIndex: request.cellIndex,
        imagePath: candidatePath,
        image: image,
        neighbours: neighbours,
        cellScore: cellScore,
        tier: tier,
        failureReason: pickFailureReason(image, neighbours, tier, config),
        computedAt: DateTime.now(),
      );

      if (best == null || candidate.cellScore > best.cellScore) {
        best = candidate;
      }
    }

    return CellQualityResult(
      cellIndex: best!.cellIndex,
      imagePath: best.imagePath,
      image: best.image,
      neighbours: best.neighbours,
      cellScore: best.cellScore,
      tier: best.tier,
      failureReason: best.failureReason,
      computedAt: best.computedAt,
      allShotScores: allShotScores,
    );
  } finally {
    for (final dispose in disposables) {
      dispose();
    }
  }
}

class _ImageFeatures {
  const _ImageFeatures({
    required this.keypoints,
    required this.descriptors,
    required this.width,
    required this.height,
    required this.sharpness,
    required this.contrast,
  });

  final cv.VecKeyPoint keypoints;
  final cv.Mat descriptors;
  final int width;
  final int height;
  final double sharpness;
  final double contrast;
}

/// A fitted 3x3 transform as plain scalars (never a native Mat) — extracted
/// from OpenCV's result and immediately disposed, so downstream direction/
/// scale math never has to think about native lifetime.
class _Transform {
  const _Transform(
    this.h00,
    this.h01,
    this.h02,
    this.h10,
    this.h11,
    this.h12,
    this.h20,
    this.h21,
    this.h22,
  );

  final double h00, h01, h02, h10, h11, h12, h20, h21, h22;

  (double x, double y) apply(double x, double y) {
    final wx = h00 * x + h01 * y + h02;
    final wy = h10 * x + h11 * y + h12;
    final w = h20 * x + h21 * y + h22;
    return (wx / w, wy / w);
  }

  double get affineDeterminant => h00 * h11 - h01 * h10;
}

// ===========================================================================
// Tier 1 — per-image SIFT score
// ===========================================================================

ImageQualityMetrics _scoreImage(
  _ImageFeatures features,
  Set<EdgeSide> relevantEdges,
  CaptureQualityConfig config,
) {
  final width = features.width;
  final height = features.height;
  final keypoints = features.keypoints;
  final keypointCount = keypoints.length;
  final megapixels = (width * height) / 1e6;
  final keypointDensity = megapixels > 0 ? keypointCount / megapixels : 0.0;

  final gridSize = config.spatialGridSize;
  final occupied = List.generate(gridSize, (_) => List.filled(gridSize, false));
  for (final kp in keypoints) {
    final gx = ((kp.x / width) * gridSize).floor().clamp(0, gridSize - 1);
    final gy = ((kp.y / height) * gridSize).floor().clamp(0, gridSize - 1);
    occupied[gy][gx] = true;
  }
  final occupiedCount = occupied.expand((row) => row).where((v) => v).length;
  final spatialDistribution = occupiedCount / (gridSize * gridSize);

  final stripW = width * config.edgeStripFraction;
  final stripH = height * config.edgeStripFraction;
  final edgeCounts = <EdgeSide, int>{};
  for (final side in EdgeSide.values) {
    var count = 0;
    for (final kp in keypoints) {
      final inStrip = switch (side) {
        EdgeSide.left => kp.x <= stripW,
        EdgeSide.right => kp.x >= width - stripW,
        EdgeSide.top => kp.y <= stripH,
        EdgeSide.bottom => kp.y >= height - stripH,
      };
      if (inStrip) count++;
    }
    edgeCounts[side] = count;
  }

  var relevantEdgeDensity = 0.0;
  if (relevantEdges.isNotEmpty) {
    final relevantCount = relevantEdges.fold<int>(0, (sum, s) => sum + (edgeCounts[s] ?? 0));
    final stripAreaPx = relevantEdges.fold<double>(0.0, (sum, s) {
      final horizontal = s == EdgeSide.left || s == EdgeSide.right;
      return sum + (horizontal ? stripW * height : stripH * width);
    });
    final stripAreaMp = stripAreaPx / 1e6;
    relevantEdgeDensity = stripAreaMp > 0 ? relevantCount / stripAreaMp : 0.0;
  }

  final keypointDensityScore = _normalized01(keypointDensity, config.keypointDensityFullScore) * 100;
  final spatialDistributionScore = spatialDistribution * 100;
  final relevantEdgeDensityScore = _normalized01(relevantEdgeDensity, config.edgeDensityFullScore) * 100;
  final sharpnessScore = _normalized01(features.sharpness, config.sharpnessFullScore) * 100;
  final contrastScore = _normalized01(features.contrast, config.contrastFullScore) * 100;

  // Blank-frame gate: below this contrast, treat the frame as having no
  // real content and don't let keypoint/spatial terms (which noise on a
  // near-flat frame can still trigger) rescue the score — see
  // CaptureQualityConfig.blankContrastFloor.
  final isBlank = features.contrast < config.blankContrastFloor;
  final imageScore = isBlank
      ? 0.0
      : config.weightKeypointDensity * keypointDensityScore +
            config.weightSpatialDistribution * spatialDistributionScore +
            config.weightRelevantEdgeDensity * relevantEdgeDensityScore +
            config.weightSharpness * sharpnessScore +
            config.weightContrast * contrastScore;

  return ImageQualityMetrics(
    keypointCount: keypointCount,
    keypointDensity: keypointDensity,
    spatialDistribution: spatialDistribution,
    edgeKeypoints: edgeCounts,
    relevantEdgeDensity: relevantEdgeDensity,
    sharpness: features.sharpness,
    contrast: features.contrast,
    imageScore: imageScore.clamp(0, 100),
  );
}

// ===========================================================================
// Tier 2/3 — neighbour matching + RANSAC filtering
// ===========================================================================

({List<cv.Point2f> src, List<cv.Point2f> dst, int goodCount}) _matchPoints({
  required cv.BFMatcher matcher,
  required _ImageFeatures from,
  required _ImageFeatures to,
  required double ratio,
}) {
  final knn = matcher.knnMatch(from.descriptors, to.descriptors, 2);
  final src = <cv.Point2f>[];
  final dst = <cv.Point2f>[];
  for (final pair in knn) {
    if (pair.length == 2 && pair[0].distance < ratio * pair[1].distance) {
      final m = pair[0];
      final fromKp = from.keypoints[m.queryIdx];
      final toKp = to.keypoints[m.trainIdx];
      src.add(cv.Point2f(fromKp.x, fromKp.y));
      dst.add(cv.Point2f(toKp.x, toKp.y));
    }
  }
  knn.dispose();
  return (src: src, dst: dst, goodCount: src.length);
}

/// Fits src->dst per [CaptureQualityConfig.transformModel], RANSAC-filtered
/// — mirrors `Stitcher.fit_transform`. Returns null when OpenCV can't fit
/// anything (degenerate/too-few points), same as stitch.py's "M is None".
({_Transform transform, int inliers})? _fitTransform({
  required List<cv.Point2f> src,
  required List<cv.Point2f> dst,
  required CaptureQualityConfig config,
}) {
  final srcVec = cv.VecPoint2f.fromList(src);
  final dstVec = cv.VecPoint2f.fromList(dst);
  try {
    if (config.transformModel == TransformModel.homography) {
      final mask = cv.Mat.empty();
      final srcMat = cv.Mat.fromVec(srcVec);
      final dstMat = cv.Mat.fromVec(dstVec);
      try {
        final h = cv.findHomography(
          srcMat,
          dstMat,
          method: cv.RANSAC,
          ransacReprojThreshold: config.ransacReprojThreshold,
          mask: mask,
        );
        if (h.rows < 3 || h.cols < 3) {
          h.dispose();
          return null;
        }
        final transform = _Transform(
          h.at<double>(0, 0), h.at<double>(0, 1), h.at<double>(0, 2),
          h.at<double>(1, 0), h.at<double>(1, 1), h.at<double>(1, 2),
          h.at<double>(2, 0), h.at<double>(2, 1), h.at<double>(2, 2),
        );
        final inliers = mask.countNoneZero;
        h.dispose();
        return (transform: transform, inliers: inliers);
      } finally {
        srcMat.dispose();
        dstMat.dispose();
        mask.dispose();
      }
    }

    final (a, inliersMask) = cv.estimateAffine2D(
      srcVec,
      dstVec,
      method: cv.RANSAC,
      ransacReprojThreshold: config.ransacReprojThreshold,
    );
    try {
      if (a.rows < 2 || a.cols < 3) return null;
      final transform = _Transform(
        a.at<double>(0, 0), a.at<double>(0, 1), a.at<double>(0, 2),
        a.at<double>(1, 0), a.at<double>(1, 1), a.at<double>(1, 2),
        0, 0, 1,
      );
      return (transform: transform, inliers: inliersMask.countNoneZero);
    } finally {
      a.dispose();
      inliersMask.dispose();
    }
  } finally {
    srcVec.dispose();
    dstVec.dispose();
  }
}

/// Measures a join's motion and flags disagreement with the expected grid
/// direction — mirrors `Stitcher.check_direction`, generalized from
/// stitch.py's right/below-only pair to all four directions: [transform]
/// maps the NEIGHBOUR into the CURRENT cell's frame, so the neighbour's
/// transformed centre should be displaced FROM the current cell TOWARDS
/// [direction].
({double dx, double dy, double scale, bool directionOk, bool scaleOk}) _checkDirection({
  required _Transform transform,
  required int width,
  required int height,
  required NeighbourDirection direction,
  required CaptureQualityConfig config,
}) {
  final cx = width / 2.0;
  final cy = height / 2.0;
  final (projX, projY) = transform.apply(cx, cy);
  final dx = projX - cx;
  final dy = projY - cy;

  final horizontal = direction == NeighbourDirection.left || direction == NeighbourDirection.right;
  final along = horizontal ? dx : dy;
  final across = horizontal ? dy : dx;
  final expectPositive = direction == NeighbourDirection.right || direction == NeighbourDirection.bottom;
  final signOk = expectPositive ? along > 0 : along < 0;
  final dominanceOk = along.abs() >= config.dirDominance * across.abs();

  final scale = math.sqrt(transform.affineDeterminant.abs());
  final scaleOk = scale >= config.minScale && scale <= config.maxScale;

  return (dx: dx, dy: dy, scale: scale, directionOk: signOk && dominanceOk, scaleOk: scaleOk);
}

NeighbourMatchMetrics _scoreNeighbour({
  required cv.BFMatcher matcher,
  required _ImageFeatures self,
  required _ImageFeatures neighbour,
  required NeighbourDirection direction,
  required int neighbourCellIndex,
  required CaptureQualityConfig config,
}) {
  // Registers the neighbour into THIS cell's frame (src=neighbour,
  // dst=self) so the measured offset tells us where the neighbour lands
  // relative to this cell.
  final matched = _matchPoints(matcher: matcher, from: neighbour, to: self, ratio: config.loweRatio);

  var ransacInliers = 0;
  var dx = 0.0, dy = 0.0, scale = 0.0;
  var directionOk = false;
  var scaleOk = false;

  if (matched.goodCount >= config.minGoodMatches) {
    final fit = _fitTransform(src: matched.src, dst: matched.dst, config: config);
    if (fit != null) {
      ransacInliers = fit.inliers;
      final checked = _checkDirection(
        transform: fit.transform,
        width: neighbour.width,
        height: neighbour.height,
        direction: direction,
        config: config,
      );
      dx = checked.dx;
      dy = checked.dy;
      scale = checked.scale;
      directionOk = checked.directionOk;
      scaleOk = checked.scaleOk;
    }
  }

  final inlierRatio = matched.goodCount > 0 ? ransacInliers / matched.goodCount : 0.0;

  final goodMatchScore = _normalized01(matched.goodCount.toDouble(), config.goodMatchesFullScore) * 100;
  final ransacInlierScore = _normalized01(ransacInliers.toDouble(), config.ransacInliersFullScore) * 100;
  final inlierRatioScore = inlierRatio.clamp(0.0, 1.0) * 100;
  final directionScore = directionOk ? 100.0 : 0.0;
  final scaleAndOverlapScore = scaleOk ? 100.0 : 0.0;

  final neighbourScore = config.weightGoodMatchScore * goodMatchScore +
      config.weightRansacInlierScore * ransacInlierScore +
      config.weightInlierRatio * inlierRatioScore +
      config.weightDirectionScore * directionScore +
      config.weightScaleAndOverlapScore * scaleAndOverlapScore;

  return NeighbourMatchMetrics(
    direction: direction,
    neighbourCellIndex: neighbourCellIndex,
    goodMatches: matched.goodCount,
    ransacInliers: ransacInliers,
    inlierRatio: inlierRatio,
    dx: dx,
    dy: dy,
    scale: scale,
    directionOk: directionOk,
    scaleOk: scaleOk,
    neighbourScore: neighbourScore.clamp(0, 100),
  );
}

// ===========================================================================
// Combined cell score + failure reason
// ===========================================================================

double _combineCellScore(
  ImageQualityMetrics image,
  List<NeighbourMatchMetrics> neighbours,
  CaptureQualityConfig config,
) {
  if (neighbours.isEmpty) return image.imageScore;

  final neighbourScore = switch (config.neighbourCombineMode) {
    NeighbourCombineMode.average =>
      neighbours.map((n) => n.neighbourScore).reduce((a, b) => a + b) / neighbours.length,
    NeighbourCombineMode.worstCase => neighbours.map((n) => n.neighbourScore).reduce(math.min),
  };

  return (config.weightImageScore * image.imageScore + config.weightNeighbourScore * neighbourScore)
      .clamp(0, 100);
}

/// Picks the single lowest-scoring contributing metric and returns its
/// human message (spec §6) — null for a yellow/green [tier]. Spec §6 is
/// explicit that only "a red or orange result should say why"; a boolean
/// pass/fail component (direction/scale) failing on one join out of several
/// is common on an otherwise-excellent, green-tier cell (e.g. a scale ratio
/// of 0.47 against a 0.5 floor) and must not trigger a "wrong position"
/// scare on a shot that's actually fine.
String? pickFailureReason(
  ImageQualityMetrics image,
  List<NeighbourMatchMetrics> neighbours,
  QualityTier tier,
  CaptureQualityConfig config,
) {
  if (tier != QualityTier.red && tier != QualityTier.orange) return null;

  const blank = 'Image looks blank or far too dark — check the lens/lighting and retake.';
  if (image.contrast < config.blankContrastFloor) return blank;

  const blurry = 'Image is too blurry — hold the phone steady and retake.';
  const weakEdge = "Not enough detail near the edge that needs to connect — move closer or reframe.";
  const noisyMatch = "This doesn't line up reliably with the last photo — include more of the same area.";
  const wrongPosition = "This photo doesn't seem to be in the right position — check you're capturing the correct cell.";

  final candidates = <(double score, String message)>[
    (_normalized01(image.sharpness, config.sharpnessFullScore) * 100, blurry),
    (image.spatialDistribution * 100, weakEdge),
    (_normalized01(image.relevantEdgeDensity, config.edgeDensityFullScore) * 100, weakEdge),
  ];

  for (final n in neighbours) {
    candidates.add((_normalized01(n.ransacInliers.toDouble(), config.ransacInliersFullScore) * 100, noisyMatch));
    candidates.add((n.inlierRatio.clamp(0.0, 1.0) * 100, noisyMatch));
    if (!n.directionOk || !n.scaleOk) {
      candidates.add((0, wrongPosition));
    }
  }

  candidates.sort((a, b) => a.$1.compareTo(b.$1));
  return candidates.first.$2;
}

double _normalized01(double value, double fullScoreAnchor) {
  if (fullScoreAnchor <= 0) return 0;
  return (value / fullScoreAnchor).clamp(0.0, 1.0);
}
