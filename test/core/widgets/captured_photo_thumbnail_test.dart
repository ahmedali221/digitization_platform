import 'package:digitization_platform/core/widgets/captured_photo_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpThumbnail(WidgetTester tester, {required VoidCallback? onTap, String? label}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CapturedPhotoThumbnail(path: 'no/such/photo.jpg', onTap: onTap, label: label),
          ),
        ),
      ),
    );
  }

  testWidgets('opens when tapped', (tester) async {
    var taps = 0;
    await pumpThumbnail(tester, onTap: () => taps++);

    await tester.tap(find.byType(CapturedPhotoThumbnail));

    expect(taps, 1);
  });

  testWidgets('does not respond while the camera is busy', (tester) async {
    await pumpThumbnail(tester, onTap: null);

    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  testWidgets('is big enough for a gloved finger', (tester) async {
    await pumpThumbnail(tester, onTap: () {});

    final size = tester.getSize(find.byType(CapturedPhotoThumbnail));
    expect(size.shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('names its cell, when it has one', (tester) async {
    await pumpThumbnail(tester, onTap: () {}, label: 'R1C2');

    expect(find.text('R1C2'), findsOneWidget);
  });
}
