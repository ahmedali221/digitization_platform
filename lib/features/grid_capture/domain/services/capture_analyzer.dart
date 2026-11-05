import 'dart:io';
import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../../../core/vision/keypoint_matching.dart';
import '../entities/capture_quality.dart';
import 'capture_quality_config.dart';
import 'cell_quality_analyzer.dart';

export 'cell_quality_analyzer.dart' show CellQualityRequest, NeighbourImageInput;

/// Runs Tier 1 (always) and Tier 2/3 (for every neighbour already captured),
/// entirely inside whichever isolate the caller runs it in. Blocks for seconds
/// at a time, so the app calls it through `CaptureAnalyzerIsolate`, never from
/// the main isolate. It has no Flutter dependency, so it's also directly
/// reusable from a host-side (non-Flutter) validation script.
///
/// Mirrors stitch.py's `Stitcher` (features/match_points/fit_transform/
/// check_direction) using the same underlying OpenCV core via opencv_dart, but
/// on a bounded copy of each photo (see
/// [CaptureQualityConfig.analysisMaxLongSide]). Keypoint and match counts are
/// therefore lower than the backend's `--audit` for the same photos.
///
/// [cache] keeps features for the next call; without one, they last this call
/// only. A cache must only ever be used with one [CaptureQualityConfig].
CellQualityResult analyzeCellQuality(
  CellQualityRequest request, {
  ImageFeatureCache? cache,
}) {
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
  final features = cache ?? ImageFeatureCache();

  try {
    _ImageFeatures featuresFor(String path) {
      final key = _cacheKey(path);
      return features._lookup(key) ?? features._store(key, _extractFeatures(path, sift, config));
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
        final pairKey =
            '${_cacheKey(candidatePath)}>${_cacheKey(n.imagePath)}|${n.direction.name}|${n.cellIndex}';
        neighbours.add(
          features._lookupPair(pairKey) ??
              features._storePair(
                pairKey,
                _scoreNeighbour(
                  matcher: matcher,
                  self: self,
                  neighbour: featuresFor(n.imagePath),
                  direction: n.direction,
                  neighbourCellIndex: n.cellIndex,
                  config: config,
                ),
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
    sift.dispose();
    matcher.dispose();
    if (cache == null) features.dispose();
  }
}

/// Includes size and modified time because a retake can land back on a deleted
/// shot's path.
String _cacheKey(String path) {
  final stat = File(path).statSync();
  return '$path|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
}

/// Sharpness and contrast come from the full-size photo, because downscaling
/// moves sharpness unpredictably (up on some photos, down on others) and its
/// score anchors were set for full-size images. SIFT and everything built on
/// its keypoints use the bounded copy: that cost is what freezes a phone
/// otherwise, since SIFT doubles the image and brute-force matching is
/// keypoints x keypoints.
_ImageFeatures _extractFeatures(String path, cv.SIFT sift, CaptureQualityConfig config) {
  final full = cv.imread(path, flags: cv.IMREAD_GRAYSCALE);
  try {
    if (full.rows == 0 || full.cols == 0) {
      throw StateError('capture_analyzer: unreadable image at $path');
    }

    final laplacian = cv.laplacian(full, cv.MatType.CV_64F);
    final sharpness = laplacian.variance().val1;
    laplacian.dispose();
    final (mean, stddev) = cv.meanStdDev(full);
    final contrast = stddev.val1;
    mean.dispose();
    stddev.dispose();

    final scale = config.analysisMaxLongSide / math.max(full.rows, full.cols);
    final bounded = scale < 1
        ? cv.resize(full, (
            (full.cols * scale).round(),
            (full.rows * scale).round(),
          ), interpolation: cv.INTER_AREA)
        : full;
    try {
      final (keypoints, descriptors) = sift.detectAndCompute(bounded, cv.Mat.empty());
      return _ImageFeatures(
        keypoints: keypoints,
        descriptors: descriptors,
        width: bounded.cols,
        height: bounded.rows,
        sharpness: sharpness,
        contrast: contrast,
      );
    } finally {
      if (!identical(bounded, full)) bounded.dispose();
    }
  } finally {
    full.dispose();
  }
}

/// Features and match results already computed, so rescoring a cell only pays
/// for what changed. A shot rescores every shot of its cell and its neighbours,
/// and matching is the slow part: about 3 s per pair on a phone. Evicts the
/// least recently used image past [capacity], and holds native memory until
/// evicted or disposed.
class ImageFeatureCache {
  /// [capacity] must leave room for a cell's current shot plus its four
  /// neighbours, which are all in use at once. Null means no limit.
  ImageFeatureCache({this.capacity}) : assert(capacity == null || capacity >= 5);

  /// Match results are small plain objects, so far more of them fit than
  /// images: one image pairs with several others.
  static const int _pairsPerImage = 8;

  final int? capacity;
  final Map<String, _ImageFeatures> _entries = {};
  final Map<String, NeighbourMatchMetrics> _pairs = {};

  NeighbourMatchMetrics? _lookupPair(String key) {
    final found = _pairs.remove(key);
    if (found != null) _pairs[key] = found;
    return found;
  }

  NeighbourMatchMetrics _storePair(String key, NeighbourMatchMetrics metrics) {
    _pairs[key] = metrics;
    final limit = capacity;
    while (limit != null && _pairs.length > limit * _pairsPerImage) {
      _pairs.remove(_pairs.keys.first);
    }
    return metrics;
  }

  _ImageFeatures? _lookup(String key) {
    final found = _entries.remove(key);
    if (found != null) _entries[key] = found;
    return found;
  }

  _ImageFeatures _store(String key, _ImageFeatures features) {
    _entries[key] = features;
    final limit = capacity;
    while (limit != null && _entries.length > limit) {
      _entries.remove(_entries.keys.first)!.dispose();
    }
    return features;
  }

  void dispose() {
    for (final features in _entries.values) {
      features.dispose();
    }
    _entries.clear();
    _pairs.clear();
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

  /// Of the bounded copy, the same coordinates as [keypoints].
  final int width;
  final int height;

  /// Of the full-size photo.
  final double sharpness;
  final double contrast;

  void dispose() {
    keypoints.dispose();
    descriptors.dispose();
  }
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
}) => matchKeypoints(
  matcher: matcher,
  fromKeypoints: from.keypoints,
  fromDescriptors: from.descriptors,
  toKeypoints: to.keypoints,
  toDescriptors: to.descriptors,
  ratio: ratio,
);

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
  // A blank/too-dark image can't be rescued by a good neighbour match — the
  // operator still has to retake it, no matter how well it happens to
  // geometrically register. See blankContrastFloor.
  if (image.contrast < config.blankContrastFloor) return 0.0;
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
