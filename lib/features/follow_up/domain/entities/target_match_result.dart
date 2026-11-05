import 'follow_up_package.dart';

/// What comparing a new photograph of a target with its video's first frame
/// found. Plain data, so it can cross the `compute()` isolate boundary.
class TargetMatchResult {
  const TargetMatchResult({
    required this.matched,
    required this.frameFound,
    required this.goodMatches,
    required this.inliers,
    required this.frameInsidePhoto,
    required this.frameCorners,
  });

  /// The whole frame was found in the photograph, so no warning is needed.
  final bool matched;

  /// The photograph shows what the video shows, whether or not all of it fits.
  /// False for another wall: RANSAC always agrees on a few accidental points,
  /// so a non-zero [inliers] alone doesn't mean anything was found.
  final bool frameFound;
  final int goodMatches;
  final int inliers;

  /// Every corner of the frame lies within the photograph. When false, part of
  /// what the video shows is missing from it.
  final bool frameInsidePhoto;

  /// Where the frame's corners lie in the photograph, clockwise from top-left,
  /// when it was found there. The dashboard's editor starts its handles here.
  final List<NormalizedPoint>? frameCorners;

  Map<String, Object> toJson() => {
    'matched': matched,
    'frame_found': frameFound,
    'good_matches': goodMatches,
    'inliers': inliers,
    'frame_inside_photo': frameInsidePhoto,
  };
}
