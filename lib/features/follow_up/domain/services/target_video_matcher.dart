import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../../../../core/vision/keypoint_matching.dart';
import '../entities/target_match_result.dart';
import 'target_match_rules.dart';

export 'target_match_rules.dart';

class TargetMatchRequest {
  const TargetMatchRequest({
    required this.photoPath,
    required this.framePath,
    this.config = const TargetMatchConfig(),
  });

  final String photoPath;
  final String framePath;
  final TargetMatchConfig config;
}

/// Finds a target's video frame inside a new photograph of it. Runs inside
/// whichever isolate calls it: the caller dispatches it through `compute()`,
/// because SIFT on the UI thread would freeze the screen.
TargetMatchResult matchTargetToVideoFrame(TargetMatchRequest request) {
  final config = request.config;
  final disposables = <void Function()>[];

  cv.Mat grayAtSize(String path) {
    final image = cv.imread(path);
    disposables.add(image.dispose);
    if (image.rows == 0 || image.cols == 0) {
      throw StateError('target_video_matcher: unreadable image at $path');
    }
    final gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY);
    disposables.add(gray.dispose);
    final scale = config.longEdge / math.max(gray.rows, gray.cols);
    if (scale >= 1) return gray;
    final small = cv.resize(gray, (
      (gray.cols * scale).round(),
      (gray.rows * scale).round(),
    ), interpolation: cv.INTER_AREA);
    disposables.add(small.dispose);
    return small;
  }

  final sift = cv.SIFT.create(descriptorType: cv.MatType.CV_32F);
  final matcher = cv.BFMatcher.create();
  disposables
    ..add(sift.dispose)
    ..add(matcher.dispose);

  try {
    final frame = grayAtSize(request.framePath);
    final photo = grayAtSize(request.photoPath);

    final (frameKeypoints, frameDescriptors) = sift.detectAndCompute(frame, cv.Mat.empty());
    final (photoKeypoints, photoDescriptors) = sift.detectAndCompute(photo, cv.Mat.empty());
    disposables
      ..add(frameKeypoints.dispose)
      ..add(frameDescriptors.dispose)
      ..add(photoKeypoints.dispose)
      ..add(photoDescriptors.dispose);

    const noMatch = TargetMatchResult(
      matched: false,
      frameFound: false,
      goodMatches: 0,
      inliers: 0,
      frameInsidePhoto: false,
      frameCorners: null,
    );

    // knnMatch needs a descriptor to compare: a blank photo has none.
    if (frameDescriptors.isEmpty || photoDescriptors.isEmpty) return noMatch;

    final matches = matchKeypoints(
      matcher: matcher,
      fromKeypoints: frameKeypoints,
      fromDescriptors: frameDescriptors,
      toKeypoints: photoKeypoints,
      toDescriptors: photoDescriptors,
      ratio: config.loweRatio,
    );

    // findHomography needs four pairs, and anything near that is coincidence.
    if (matches.goodCount < 4) {
      return TargetMatchResult(
        matched: false,
        frameFound: false,
        goodMatches: matches.goodCount,
        inliers: 0,
        frameInsidePhoto: false,
        frameCorners: null,
      );
    }

    final fitted = _fitHomography(matches.src, matches.dst, config);
    if (fitted == null) {
      return TargetMatchResult(
        matched: false,
        frameFound: false,
        goodMatches: matches.goodCount,
        inliers: 0,
        frameInsidePhoto: false,
        frameCorners: null,
      );
    }

    return evaluateFrameInPhoto(
      goodMatches: matches.goodCount,
      inliers: fitted.inliers,
      frameWidth: frame.cols.toDouble(),
      frameHeight: frame.rows.toDouble(),
      photoWidth: photo.cols.toDouble(),
      photoHeight: photo.rows.toDouble(),
      project: fitted.project,
      config: config,
    );
  } finally {
    for (final dispose in disposables.reversed) {
      dispose();
    }
  }
}

({(double, double) Function(double, double) project, int inliers})? _fitHomography(
  List<cv.Point2f> src,
  List<cv.Point2f> dst,
  TargetMatchConfig config,
) {
  final srcVec = cv.VecPoint2f.fromList(src);
  final dstVec = cv.VecPoint2f.fromList(dst);
  final srcMat = cv.Mat.fromVec(srcVec);
  final dstMat = cv.Mat.fromVec(dstVec);
  final mask = cv.Mat.empty();
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
    final m = [
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++) h.at<double>(row, col),
    ];
    h.dispose();

    return (
      project: (double x, double y) {
        final w = m[6] * x + m[7] * y + m[8];
        return ((m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w);
      },
      inliers: mask.countNoneZero,
    );
  } finally {
    srcMat.dispose();
    dstMat.dispose();
    mask.dispose();
    srcVec.dispose();
    dstVec.dispose();
  }
}
