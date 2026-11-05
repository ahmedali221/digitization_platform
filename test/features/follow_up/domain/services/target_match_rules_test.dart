import 'package:digitization_platform/features/follow_up/domain/services/target_match_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules deciding what the operator is warned about, given where a fitted
/// transform put the video's frame in the photograph.
void main() {
  const frame = 1000.0;
  const photo = 2000.0;

  (double, double) Function(double, double) placed({
    double scale = 1,
    double dx = 500,
    double dy = 500,
  }) => (x, y) => (x * scale + dx, y * scale + dy);

  test('the whole frame inside the photograph with plenty of matches needs no warning', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: placed(),
    );

    expect(result.matched, isTrue);
    expect(result.frameInsidePhoto, isTrue);
    expect(result.frameCorners, hasLength(4));
    expect(result.frameCorners!.first.x, closeTo(0.25, 1e-9));
    expect(result.frameCorners!.first.y, closeTo(0.25, 1e-9));
    expect(result.frameCorners![2].x, closeTo(0.75, 1e-9));
  });

  test('too few agreeing matches warns, and offers no corners to start from', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 40,
      inliers: 12,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: placed(),
    );

    expect(result.matched, isFalse);
    expect(result.frameFound, isFalse, reason: 'a few agreeing points is what any other wall gives');
    expect(result.frameCorners, isNull);
  });

  test('part of the frame outside the photograph warns', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: placed(dx: 1500),
    );

    expect(result.matched, isFalse);
    expect(result.frameInsidePhoto, isFalse);
    expect(result.frameFound, isTrue, reason: 'so the operator is told to include all of it');
    expect(result.frameCorners, isNull);
  });

  test('a corner just past the edge still counts, and is put on the photograph', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: placed(dx: -20),
    );

    expect(result.matched, isTrue);
    expect(result.frameCorners!.first.x, 0);
  });

  test('a transform mirroring the frame is a false match', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: (x, y) => (y + 500, x + 500),
    );

    expect(result.matched, isFalse);
    expect(result.frameCorners, isNull);
  });

  test('a transform folding the frame over itself is a false match', () {
    final corners = <(double, double)>[(500, 500), (1500, 1500), (1500, 500), (500, 1500)];
    var next = 0;
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: (_, _) => corners[next++],
    );

    expect(result.matched, isFalse);
    expect(result.frameCorners, isNull);
  });

  test('a real perspective, near edge larger than the far one, is fine', () {
    final corners = <(double, double)>[(600, 500), (1500, 400), (1500, 1600), (600, 1500)];
    var next = 0;
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: (_, _) => corners[next++],
    );

    expect(result.matched, isTrue);
    expect(result.frameCorners![1].y, closeTo(0.2, 1e-9));
  });

  test('a frame shrunk to a speck is a false match', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: placed(scale: 0.05),
    );

    expect(result.matched, isFalse);
  });

  test('a transform sending a corner to infinity is a false match', () {
    final result = evaluateFrameInPhoto(
      goodMatches: 200,
      inliers: 120,
      frameWidth: frame,
      frameHeight: frame,
      photoWidth: photo,
      photoHeight: photo,
      project: (x, y) => (x / 0, y),
    );

    expect(result.matched, isFalse);
  });
}
