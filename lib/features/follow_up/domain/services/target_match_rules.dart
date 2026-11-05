import '../entities/follow_up_package.dart';
import '../entities/target_match_result.dart';

/// Thresholds for the target check. A starting point with no measurements behind
/// it yet: set them from real target/video pairs and real re-shots. It only ever
/// warns, because the operator decides, and a person reviews it on the dashboard.
class TargetMatchConfig {
  const TargetMatchConfig({
    this.longEdge = 1200,
    this.loweRatio = 0.75,
    this.ransacReprojThreshold = 5.0,
    this.minInliers = 30,
    this.edgeTolerance = 0.02,
    this.minFrameArea = 0.02,
  });

  /// Both images are compared at this size: a full-size photo adds time, not
  /// matches, against a frame this big.
  final int longEdge;
  final double loweRatio;
  final double ransacReprojThreshold;
  final int minInliers;

  /// How far outside the photograph a corner may land, as a fraction of its
  /// size, and still count as inside. A wall's edge is rarely exact.
  final double edgeTolerance;

  /// Smaller than this, as a fraction of the photograph, is a false match.
  final double minFrameArea;
}

/// Judges where a fitted transform puts the frame in the photograph. No OpenCV
/// in here, so the rules can be tested anywhere.
TargetMatchResult evaluateFrameInPhoto({
  required int goodMatches,
  required int inliers,
  required double frameWidth,
  required double frameHeight,
  required double photoWidth,
  required double photoHeight,
  required (double, double) Function(double x, double y) project,
  TargetMatchConfig config = const TargetMatchConfig(),
}) {
  final projected = [
    project(0, 0),
    project(frameWidth, 0),
    project(frameWidth, frameHeight),
    project(0, frameHeight),
  ].map((point) => (point.$1 / photoWidth, point.$2 / photoHeight)).toList();

  final isFinite = projected.every((p) => p.$1.isFinite && p.$2.isFinite);
  final plausible = isFinite && _keepsItsShape(projected) && _area(projected) >= config.minFrameArea;

  if (!plausible) {
    return TargetMatchResult(
      matched: false,
      frameFound: false,
      goodMatches: goodMatches,
      inliers: inliers,
      frameInsidePhoto: false,
      frameCorners: null,
    );
  }

  final tolerance = config.edgeTolerance;
  final inside = projected.every(
    (p) =>
        p.$1 >= -tolerance &&
        p.$1 <= 1 + tolerance &&
        p.$2 >= -tolerance &&
        p.$2 <= 1 + tolerance,
  );

  final found = inliers >= config.minInliers;

  return TargetMatchResult(
    matched: inside && found,
    frameFound: found,
    goodMatches: goodMatches,
    inliers: inliers,
    frameInsidePhoto: inside,
    // Only when usable as the editor's starting handles, which must lie on the photo.
    frameCorners: inside && found
        ? [
            for (final p in projected)
              NormalizedPoint(p.$1.clamp(0.0, 1.0), p.$2.clamp(0.0, 1.0)),
          ]
        : null,
  );
}

double _area(List<(double, double)> quad) {
  var twice = 0.0;
  for (var i = 0; i < quad.length; i++) {
    final next = quad[(i + 1) % quad.length];
    twice += quad[i].$1 * next.$2 - next.$1 * quad[i].$2;
  }
  return twice.abs() / 2;
}

/// Every turn of the frame's outline goes the way it does in the frame itself,
/// clockwise. A homography that folds the frame over itself or mirrors it is a
/// false match: a photograph of a wall is never its mirror image.
bool _keepsItsShape(List<(double, double)> quad) {
  for (var i = 0; i < quad.length; i++) {
    final a = quad[i];
    final b = quad[(i + 1) % quad.length];
    final c = quad[(i + 2) % quad.length];
    final cross = (b.$1 - a.$1) * (c.$2 - b.$2) - (b.$2 - a.$2) * (c.$1 - b.$1);
    if (cross <= 0) return false;
  }
  return true;
}
