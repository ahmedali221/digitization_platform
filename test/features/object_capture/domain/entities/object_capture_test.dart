import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/object_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final takenAt = DateTime(2026, 11, 13);

  ObjectPhoto side(ObjectSide side) =>
      ObjectPhoto(path: '${side.name}.jpg', capturedAt: takenAt, side: side);

  ObjectPhoto free(String name, {String comment = ''}) =>
      ObjectPhoto(path: '$name.jpg', capturedAt: takenAt, comment: comment);

  ObjectCapture allSixSides() =>
      ObjectCapture(photos: ObjectSide.values.map(side).toList());

  test('nothing photographed is neither complete nor anything else', () {
    expect(ObjectCapture.empty.isEmpty, isTrue);
    expect(ObjectCapture.empty.isComplete, isFalse);
    expect(ObjectCapture.empty.sidesCaptured, 0);
  });

  test('an organised capture is complete at six sides, not before', () {
    final five = ObjectCapture(
      photos: ObjectSide.values.take(5).map(side).toList(),
    );

    expect(five.isComplete, isFalse);
    expect(five.hasEverySide, isFalse);
    expect(allSixSides().isComplete, isTrue);
    expect(allSixSides().sidesCaptured, 6);
  });

  test('a free capture is complete as soon as it holds a photograph', () {
    final capture = ObjectCapture(photos: [free('a', comment: 'Back pillar')]);

    expect(capture.isComplete, isTrue);
    expect(capture.freePhotos, hasLength(1));
    expect(capture.sidePhotos, isEmpty);
  });

  test('free photographs do not finish a part-shot organised capture', () {
    final capture = ObjectCapture(
      photos: [
        side(ObjectSide.front),
        side(ObjectSide.back),
        free('detail', comment: 'Cartouche'),
      ],
    );

    expect(capture.isComplete, isFalse);
  });

  test('six sides stay complete with free photographs beside them', () {
    final capture = ObjectCapture(
      photos: [
        ...allSixSides().photos,
        free('detail', comment: 'Cartouche'),
      ],
    );

    expect(capture.isComplete, isTrue);
  });

  test('a free photograph with no description is noticed, blank ones too', () {
    expect(
      ObjectCapture(
        photos: [free('a', comment: '   ')],
      ).hasUncommentedFreePhoto,
      isTrue,
    );
    expect(
      ObjectCapture(
        photos: [
          free('a', comment: 'Lid'),
          side(ObjectSide.top),
        ],
      ).hasUncommentedFreePhoto,
      isFalse,
      reason: 'a side photograph is described by its side',
    );
  });

  test('side photographs are found by their side', () {
    final capture = ObjectCapture(
      photos: [side(ObjectSide.left), free('a'), side(ObjectSide.top)],
    );

    expect(capture.sidePhotos.keys, {ObjectSide.left, ObjectSide.top});
    expect(capture.sidePhotos[ObjectSide.left]!.path, 'left.jpg');
  });
}
