import 'package:digitization_platform/features/follow_up/presentation/widgets/captured_photo_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _missingPhoto = 'no/such/photo.jpg';

void main() {
  /// Opens the review from a button, and reports what it returned through the
  /// list, which stays empty for as long as the review is open.
  Future<List<CapturedPhotoDecision?>> openReview(
    WidgetTester tester, {
    String? label,
    bool canRetake = false,
  }) async {
    final results = <CapturedPhotoDecision?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(await reviewCapturedPhoto(context, _missingPhoto, label: label, canRetake: canRetake));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder confirmButton() =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'));

  testWidgets('deleting needs confirming', (tester) async {
    final results = await openReview(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);

    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(results, [CapturedPhotoDecision.delete]);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('cancelling the confirmation goes back to the photograph', (tester) async {
    final results = await openReview(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('only offers a retake where asked to', (tester) async {
    await openReview(tester);
    expect(find.text('Retake'), findsNothing);
  });

  testWidgets('a retake needs no confirming, since the old photograph stays until the new one', (tester) async {
    final results = await openReview(tester, canRetake: true);

    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    expect(results, [CapturedPhotoDecision.retake]);
  });

  testWidgets('closing it decides nothing', (tester) async {
    final results = await openReview(tester, canRetake: true);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('names the cell it is showing', (tester) async {
    await openReview(tester, label: 'R2C3');

    expect(find.text('R2C3'), findsOneWidget);
  });
}
