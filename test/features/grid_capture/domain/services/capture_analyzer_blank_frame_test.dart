// Regression test for the blank-frame gate (CaptureQualityConfig.
// blankContrastFloor): two visually-black photos of the same cell used to
// score differently (0 vs a false-positive ~51) because sensor noise on a
// near-black frame can still clear SIFT's own per-keypoint contrast
// threshold and scatter enough spurious keypoints to inflate the
// keypoint-density/spatial-distribution terms (55% combined weight).
//
// Fully self-contained (synthetic images generated via OpenCV itself, no
// external sample data) so it runs anywhere opencv_dart's native library is
// available.
//
// Run with:  flutter test test/features/grid_capture/domain/services/capture_analyzer_blank_frame_test.dart -d windows
import 'dart:io';

import 'package:digitization_platform/features/grid_capture/domain/entities/capture_quality.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/capture_analyzer.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/capture_quality_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('capture_analyzer_blank_frame_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String writeImage(String name, cv.Mat mat) {
    final path = p.join(tempDir.path, name);
    cv.imwrite(path, mat);
    mat.dispose();
    return path;
  }

  test('a perfectly flat black frame scores 0/red', () {
    final flatPath = writeImage('flat_black.png', cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3));

    final result = analyzeCellQuality(
      CellQualityRequest(cellIndex: 0, imagePaths: [flatPath], relevantEdges: const {}),
    );

    expect(result.image.imageScore, 0.0);
    expect(result.cellScore, 0.0);
    expect(result.tier, QualityTier.red);
    expect(result.failureReason, contains('blank'));
  });

  test('a noisy near-black frame also scores 0/red, not a false-positive orange', () {
    // Mean 3 / std 6 simulates sensor noise on a near-black real capture:
    // low enough that the measured grayscale contrast stays under
    // blankContrastFloor (8.0), but non-uniform enough that pre-fix, SIFT
    // could still find keypoints scattered widely across the frame.
    final noisyMat = cv.Mat.randn(
      600,
      800,
      cv.MatType.CV_8UC3,
      mean: cv.Scalar.all(3),
      std: cv.Scalar.all(6),
    );
    final noisyPath = writeImage('noisy_black.png', noisyMat);

    final result = analyzeCellQuality(
      CellQualityRequest(cellIndex: 0, imagePaths: [noisyPath], relevantEdges: const {}),
    );

    expect(result.image.imageScore, 0.0);
    expect(result.cellScore, 0.0);
    expect(result.tier, QualityTier.red);
    expect(result.failureReason, contains('blank'));
  });

  test('a real high-contrast pattern is not caught by the blank-frame gate', () {
    final mat = cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3);
    for (var y = 0; y < mat.rows; y += 40) {
      for (var x = 0; x < mat.cols; x += 40) {
        if (((x ~/ 40) + (y ~/ 40)) % 2 == 0) {
          cv.rectangle(mat, cv.Rect(x, y, 40, 40), cv.Scalar.all(255), thickness: -1);
        }
      }
    }
    final path = writeImage('checkerboard.png', mat);

    final result = analyzeCellQuality(
      CellQualityRequest(cellIndex: 0, imagePaths: [path], relevantEdges: const {}),
    );

    expect(result.image.imageScore, greaterThan(0));
  });

  group('cost limits', () {
    /// A dense random texture, the worst case for keypoint count.
    String writeTexture(String name, int rows, int cols) {
      final noise = cv.Mat.randu(rows, cols, cv.MatType.CV_8UC1, high: cv.Scalar.all(256));
      final blurred = cv.gaussianBlur(noise, (0, 0), 1.6);
      noise.dispose();
      return writeImage(name, blurred);
    }

    test('an oversized photo is bounded in size and keypoints', () {
      const config = CaptureQualityConfig(analysisMaxLongSide: 400, siftFeatures: 300);
      final path = writeTexture('oversized.png', 900, 1200);

      final result = analyzeCellQuality(
        CellQualityRequest(cellIndex: 0, imagePaths: [path], relevantEdges: const {}, config: config),
      );

      // SIFT can keep a few extra when strengths tie at the cut-off.
      expect(result.image.keypointCount, inInclusiveRange(1, 310));
      // Per megapixel of the 400x300 copy, not of the 1200x900 original.
      expect(result.image.keypointDensity, closeTo(result.image.keypointCount / 0.12, 0.001));
    });

    test('sharpness and contrast are read at full size', () {
      final path = writeTexture('sharp.png', 900, 1200);
      final full = analyzeCellQuality(
        CellQualityRequest(
          cellIndex: 0,
          imagePaths: [path],
          relevantEdges: const {},
          config: const CaptureQualityConfig(analysisMaxLongSide: 5000),
        ),
      );

      final bounded = analyzeCellQuality(
        CellQualityRequest(
          cellIndex: 0,
          imagePaths: [path],
          relevantEdges: const {},
          config: const CaptureQualityConfig(analysisMaxLongSide: 400),
        ),
      );

      expect(bounded.image.sharpness, full.image.sharpness);
      expect(bounded.image.contrast, full.image.contrast);
    });

    test('a cache reuses features and notices a replaced file', () {
      final cache = ImageFeatureCache(capacity: 5);
      addTearDown(cache.dispose);
      final path = writeTexture('cached.png', 300, 400);
      CellQualityResult run() => analyzeCellQuality(
        CellQualityRequest(cellIndex: 0, imagePaths: [path], relevantEdges: const {}),
        cache: cache,
      );

      final first = run();
      expect(run().image.keypointCount, first.image.keypointCount);

      // A retake can land back on a deleted shot's path.
      final replacement = cv.Mat.zeros(300, 400, cv.MatType.CV_8UC3);
      cv.imwrite(path, replacement);
      replacement.dispose();
      File(path).setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));

      expect(run().image.keypointCount, 0);
    });

    test('a cache gives the same neighbour result as computing it again', () {
      final cache = ImageFeatureCache(capacity: 5);
      addTearDown(cache.dispose);
      final self = writeTexture('pair_self.png', 300, 400);
      final neighbour = writeTexture('pair_neighbour.png', 300, 400);
      final request = CellQualityRequest(
        cellIndex: 0,
        imagePaths: [self],
        relevantEdges: const {},
        neighbours: [
          NeighbourImageInput(direction: NeighbourDirection.right, cellIndex: 1, imagePath: neighbour),
        ],
      );

      final uncached = analyzeCellQuality(request);
      final first = analyzeCellQuality(request, cache: cache);
      final second = analyzeCellQuality(request, cache: cache);

      expect(first.neighbours, uncached.neighbours);
      expect(second.neighbours, uncached.neighbours);
    });

    test('a cache keeps working past its capacity', () {
      final cache = ImageFeatureCache(capacity: 5);
      addTearDown(cache.dispose);
      final paths = [for (var i = 0; i < 8; i++) writeTexture('evict_$i.png', 200, 300)];

      final result = analyzeCellQuality(
        CellQualityRequest(cellIndex: 0, imagePaths: paths, relevantEdges: const {}),
        cache: cache,
      );

      expect(result.allShotScores, hasLength(8));
    });
  });
}
