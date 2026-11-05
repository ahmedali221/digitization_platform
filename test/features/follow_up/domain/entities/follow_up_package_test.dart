import 'dart:convert';

import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
import 'package:digitization_platform/features/follow_up/presentation/pages/crop_photo_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape the dashboard's FollowUpPackageController answers with
/// (tests/Feature/FollowUpPackageTest.php on that side).
const _manifest = '''
{
  "id": 7,
  "site": {"id": 3, "name": "Karnak"},
  "created_at": "2026-11-05T10:00:00+00:00",
  "total_bytes": 300,
  "annotations": [{
    "id": 41,
    "reference_code": "W-1",
    "wall": {"id": 9, "name": "North Wall", "location": "Temple > Hall"},
    "grade": "weak",
    "reasons": ["Too few glyphs"],
    "has_capture": false,
    "picture": {"key": "picture-panorama-1.jpg", "width": 400, "height": 200},
    "polygon": [{"x": 0.25, "y": 0.5}, {"x": 0.75, "y": 0.5}, {"x": 0.75, "y": 1}],
    "closeup_key": "closeup-41.jpg"
  }],
  "targets": [{
    "ar_key": "abcdefghij",
    "label": "Wall-1",
    "description": null,
    "wall": {"id": 9, "name": "North Wall"},
    "image_key": "target-abcdefghij.jpg",
    "video_frame_key": null,
    "has_video": false
  }],
  "files": {
    "target-abcdefghij.jpg": {"url": "https://x.test/f", "size": 300, "sha256": "abc"}
  }
}
''';

void main() {
  test('reads the manifest the dashboard writes', () {
    final package = FollowUpPackage.fromJson(jsonDecode(_manifest) as Map<String, dynamic>);

    expect(package.id, 7);
    expect(package.siteId, '3');
    expect(package.totalBytes, 300);

    final annotation = package.annotations.single;
    expect(annotation.id, 41);
    expect(annotation.grade, 'weak');
    expect(annotation.wall.location, 'Temple > Hall');
    expect(annotation.picture!.key, 'picture-panorama-1.jpg');
    expect(annotation.picture!.width, 400);
    expect(annotation.polygon, hasLength(3));
    expect(annotation.polygon[2].y, 1.0);
    expect(annotation.closeupKey, 'closeup-41.jpg');

    final target = package.targets.single;
    expect(target.arKey, 'abcdefghij');
    expect(target.videoFrameKey, isNull);
    expect(target.hasVideo, isFalse);

    expect(package.files['target-abcdefghij.jpg']!.size, 300);
  });

  test('an annotation with no wall picture still reads', () {
    final json = jsonDecode(_manifest) as Map<String, dynamic>;
    (json['annotations'] as List).first
      ..['picture'] = null
      ..['polygon'] = <dynamic>[]
      ..['closeup_key'] = null;

    final annotation = FollowUpPackage.fromJson(json).annotations.single;

    expect(annotation.picture, isNull);
    expect(annotation.polygon, isEmpty);
  });

  group('the crop box', () {
    const box = CropBox(0.2, 0.2, 0.8, 0.8);

    test('moves only the sides of the corner dragged', () {
      final moved = box.withCorner(0, 0.1, 0.3);
      expect([moved.left, moved.top, moved.right, moved.bottom], [0.1, 0.3, 0.8, 0.8]);

      final opposite = box.withCorner(2, 0.9, 0.7);
      expect([opposite.left, opposite.top, opposite.right, opposite.bottom], [0.2, 0.2, 0.9, 0.7]);
    });

    test('stays on the photograph', () {
      final moved = box.withCorner(0, -1, -1);
      expect([moved.left, moved.top], [0.0, 0.0]);

      final other = box.withCorner(2, 2, 2);
      expect([other.right, other.bottom], [1.0, 1.0]);
    });

    test('cannot collapse or cross over', () {
      final moved = box.withCorner(0, 0.95, 0.95);
      expect(moved.left, closeTo(0.8 - CropBox.minimumSize, 1e-9));
      expect(moved.top, closeTo(0.8 - CropBox.minimumSize, 1e-9));
    });
  });
}
