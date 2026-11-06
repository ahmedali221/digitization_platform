import 'dart:async';

import 'package:digitization_platform/features/follow_up/presentation/pages/crop_photo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _transition = Duration(seconds: 1);

void main() {
  /// Opens the page from a button, and reports what it popped with through the
  /// list, which stays empty for as long as the page is open.
  Future<List<bool?>> openPage(WidgetTester tester, Future<void> Function(CropBox box) onSave) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CropPhotoPage(photoPath: 'no/such/photo.jpg', onSave: onSave),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(_transition);
    return results;
  }

  testWidgets('closes with true once saved, having been given the crop', (tester) async {
    final boxes = <CropBox>[];
    final results = await openPage(tester, (box) async => boxes.add(box));

    await tester.tap(find.text('Use this crop'));
    await tester.pump();
    await tester.pump(_transition);

    expect(boxes, hasLength(1));
    expect(results, [true]);
  });

  testWidgets('stays open when saving fails, and can be tried again', (tester) async {
    var attempts = 0;
    final results = await openPage(tester, (_) async {
      attempts++;
      if (attempts == 1) throw const FormatException('disk full');
    });

    await tester.tap(find.text('Use this crop'));
    await tester.pump();
    await tester.pump(_transition);

    expect(results, isEmpty);
    expect(find.textContaining('still here'), findsOneWidget);

    await tester.tap(find.text('Use this crop'));
    await tester.pump();
    expect(find.textContaining('still here'), findsNothing);
    await tester.pump(_transition);

    expect(attempts, 2);
    expect(results, [true]);
  });

  testWidgets('holds still while saving', (tester) async {
    final holding = Completer<void>();
    var attempts = 0;
    final results = await openPage(tester, (_) {
      attempts++;
      return holding.future;
    });

    await tester.tap(find.text('Use this crop'));
    await tester.pump();

    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(attempts, 1);

    await tester.pageBack();
    await tester.pump(_transition);
    expect(results, isEmpty, reason: 'leaving would delete what is being saved');

    holding.complete();
    await tester.pump();
    await tester.pump(_transition);
    expect(results, [true]);
  });

  testWidgets('going back without saving reports nothing saved', (tester) async {
    var attempts = 0;
    final results = await openPage(tester, (_) async => attempts++);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(_transition);

    expect(results, [null]);
    expect(attempts, 0);
  });
}
