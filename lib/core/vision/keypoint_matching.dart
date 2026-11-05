import 'package:opencv_dart/opencv_dart.dart' as cv;

/// SIFT matches between two images that pass Lowe's ratio test, as point pairs.
/// Mirrors `Stitcher.match_points` in stitch.py. The one matching routine in
/// the app: the grid's quality score and the follow-up target check both use it.
({List<cv.Point2f> src, List<cv.Point2f> dst, int goodCount}) matchKeypoints({
  required cv.BFMatcher matcher,
  required cv.VecKeyPoint fromKeypoints,
  required cv.Mat fromDescriptors,
  required cv.VecKeyPoint toKeypoints,
  required cv.Mat toDescriptors,
  required double ratio,
}) {
  final knn = matcher.knnMatch(fromDescriptors, toDescriptors, 2);
  final src = <cv.Point2f>[];
  final dst = <cv.Point2f>[];
  for (final pair in knn) {
    if (pair.length == 2 && pair[0].distance < ratio * pair[1].distance) {
      final m = pair[0];
      final fromKp = fromKeypoints[m.queryIdx];
      final toKp = toKeypoints[m.trainIdx];
      src.add(cv.Point2f(fromKp.x, fromKp.y));
      dst.add(cv.Point2f(toKp.x, toKp.y));
    }
  }
  knn.dispose();
  return (src: src, dst: dst, goodCount: src.length);
}
