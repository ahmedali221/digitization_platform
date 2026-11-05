// Needs opencv_dart's native library, like capture_analyzer_blank_frame_test.dart.
//
// Run with:  flutter test test/features/follow_up/domain/services/target_video_matcher_test.dart -d windows
import 'dart:io';
import 'dart:math' as math;

import 'package:digitization_platform/features/follow_up/domain/services/shot_processing.dart';
import 'package:digitization_platform/features/follow_up/domain/services/target_video_matcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('target_matcher_'));
  tearDown(() => folder.deleteSync(recursive: true));

  /// Dense, unrepeating marks, the way carved relief gives SIFT something to hold.
  cv.Mat texture(int width, int height, int seed) {
    final random = math.Random(seed);
    final image = cv.Mat.zeros(height, width, cv.MatType.CV_8UC3);
    for (var i = 0; i < width * height ~/ 1500; i++) {
      final shade = random.nextInt(255).toDouble();
      cv.circle(
        image,
        cv.Point(random.nextInt(width), random.nextInt(height)),
        2 + random.nextInt(14),
        cv.Scalar(shade, shade, shade, 255),
        thickness: -1,
      );
    }
    return image;
  }

  String write(String name, cv.Mat image) {
    final path = p.join(folder.path, name);
    cv.imwrite(path, image);
    return path;
  }

  test('finds the frame inside a wider photograph of the same wall', () {
    final wall = texture(1600, 1200, 1);
    final frame = wall.region(cv.Rect(300, 200, 900, 700));
    final photoPath = write('photo.jpg', wall);
    final framePath = write('frame.jpg', frame);

    final result = matchTargetToVideoFrame(TargetMatchRequest(photoPath: photoPath, framePath: framePath));

    expect(result.matched, isTrue);
    expect(result.frameInsidePhoto, isTrue);
    expect(result.frameCorners, hasLength(4));
    expect(result.frameCorners![0].x, closeTo(300 / 1600, 0.02));
    expect(result.frameCorners![0].y, closeTo(200 / 1200, 0.02));
    expect(result.frameCorners![2].x, closeTo(1200 / 1600, 0.02));
    expect(result.frameCorners![2].y, closeTo(900 / 1200, 0.02));
  });

  test('warns on a photograph of a different wall', () {
    final photoPath = write('photo.jpg', texture(1600, 1200, 1));
    final framePath = write('frame.jpg', texture(900, 700, 2));

    final result = matchTargetToVideoFrame(TargetMatchRequest(photoPath: photoPath, framePath: framePath));

    expect(result.matched, isFalse);
    expect(result.frameCorners, isNull);
  });

  test('warns when part of the frame is outside the photograph', () {
    final wall = texture(1600, 1200, 1);
    final photoPath = write('photo.jpg', wall.region(cv.Rect(0, 0, 800, 1200)));
    final framePath = write('frame.jpg', wall.region(cv.Rect(400, 200, 800, 700)));

    final result = matchTargetToVideoFrame(TargetMatchRequest(photoPath: photoPath, framePath: framePath));

    expect(result.matched, isFalse);
    expect(result.frameInsidePhoto, isFalse);
  });

  test('a blank photograph warns rather than failing', () {
    final photoPath = write('photo.jpg', cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3));
    final framePath = write('frame.jpg', texture(800, 600, 1));

    final result = matchTargetToVideoFrame(TargetMatchRequest(photoPath: photoPath, framePath: framePath));

    expect(result.matched, isFalse);
  });

  test('picks the sharper of two shots', () {
    final sharp = texture(800, 600, 1);
    final blurred = cv.gaussianBlur(sharp, (31, 31), 8);
    final sharpPath = write('sharp.jpg', sharp);
    final blurredPath = write('blurred.jpg', blurred);

    final scores = measureSharpness([sharpPath, blurredPath]);

    expect(scores[sharpPath]!, greaterThan(scores[blurredPath]!));
  });

  test('crops to the box, and refuses nothing at the edges', () {
    final sourcePath = write('source.jpg', texture(1000, 500, 1));
    final targetPath = p.join(folder.path, 'crop.jpg');

    cropPhoto(CropRequest(
      sourcePath: sourcePath,
      targetPath: targetPath,
      left: 0.1,
      top: 0.2,
      right: 0.6,
      bottom: 1,
    ));

    final cropped = cv.imread(targetPath);
    expect(cropped.cols, 500);
    expect(cropped.rows, 400);
  });
}
