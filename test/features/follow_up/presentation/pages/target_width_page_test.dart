import 'dart:async';

import 'package:digitization_platform/features/follow_up/domain/entities/target_width.dart';
import 'package:digitization_platform/features/follow_up/presentation/pages/target_width_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _transition = Duration(seconds: 1);
const _arChannel = MethodChannel('nilelens/ar_measure');

void main() {
  late List<String> arCalls;

  setUp(() => arCalls = []);

  /// Answers the AR channel: a phone without AR, or with AR whose every
  /// measurement comes out at [arMeters]. Unanswered, the page waits forever.
  void mockAr(WidgetTester tester, double? arMeters) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_arChannel, (call) async {
      arCalls.add(call.method);
      return call.method == 'isSupported' ? arMeters != null : {'status': 'measured', 'meters': arMeters};
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_arChannel, null));
  }

  /// Opens the page from a button, and reports what it popped with through the
  /// list, which stays empty for as long as the page is open.
  Future<List<TargetWidth?>> openPage(
    WidgetTester tester,
    Future<void> Function(TargetWidth width) onSave, {
    bool discardsPhotograph = false,
    double? currentMeters,
    double? arMeters,
  }) async {
    mockAr(tester, arMeters);
    final results = <TargetWidth?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context).push<TargetWidth>(
                  MaterialPageRoute(
                    builder: (_) => TargetWidthPage(
                      title: 'Target',
                      imagePath: 'no/such/image.jpg',
                      onSave: onSave,
                      discardsPhotograph: discardsPhotograph,
                      currentMeters: currentMeters,
                    ),
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

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(_transition);
  }

  Future<void> typeWidth(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tapAndSettle(tester, find.text('Use this width'));
  }

  testWidgets('closes with the width once saved', (tester) async {
    final saved = <TargetWidth>[];
    final results = await openPage(tester, (width) async => saved.add(width));

    await typeWidth(tester, '1.42');

    expect(saved.single.meters, 1.42);
    expect(saved.single.source, TargetWidth.sourceManual);
    expect(results.single, same(saved.single));
  });

  testWidgets('does not try to save a width that can not be right', (tester) async {
    final saved = <TargetWidth>[];
    final results = await openPage(tester, (width) async => saved.add(width));

    await typeWidth(tester, '0');

    expect(saved, isEmpty);
    expect(results, isEmpty);
  });

  testWidgets('offers the width already known, and saves that', (tester) async {
    final saved = <TargetWidth>[];
    final results = await openPage(tester, (width) async => saved.add(width), currentMeters: 2);

    await tapAndSettle(tester, find.textContaining('Use 2'));

    expect(saved.single.meters, 2);
    expect(saved.single.source, TargetWidth.sourceExisting);
    expect(results, hasLength(1));
  });

  group('when saving fails', () {
    testWidgets('stays open and says so', (tester) async {
      final results = await openPage(tester, (_) async => throw const FormatException('disk full'));

      await typeWidth(tester, '1.42');

      expect(results, isEmpty);
      expect(find.textContaining('nothing has been lost'), findsOneWidget);
    });

    testWidgets('retries an AR measurement without measuring again', (tester) async {
      final attempts = <TargetWidth>[];
      final results = await openPage(tester, arMeters: 3.5, (width) async {
        attempts.add(width);
        if (attempts.length == 1) throw const FormatException('disk full');
      });

      await tapAndSettle(tester, find.text('Measure with AR'));
      expect(results, isEmpty);

      await tapAndSettle(tester, find.text('Try again'));

      expect(attempts.map((width) => width.meters), [3.5, 3.5]);
      expect(attempts.last.source, TargetWidth.sourceAr);
      expect(arCalls.where((method) => method == 'measure'), hasLength(1));
      expect(results.single?.meters, 3.5);
    });

    testWidgets('lets the width be changed instead', (tester) async {
      var attempts = 0;
      final saved = <double>[];
      final results = await openPage(tester, (width) async {
        attempts++;
        if (attempts == 1) throw const FormatException('disk full');
        saved.add(width.meters);
      });

      await typeWidth(tester, '1.42');
      await tapAndSettle(tester, find.text('Change the width'));
      expect(find.textContaining('nothing has been lost'), findsNothing);

      await typeWidth(tester, '1.5');

      expect(saved, [1.5]);
      expect(results, hasLength(1));
    });
  });

  group('while saving', () {
    testWidgets('going back does nothing, and asks nothing', (tester) async {
      final holding = Completer<void>();
      final results = await openPage(tester, (_) => holding.future, discardsPhotograph: true);

      await tester.enterText(find.byType(TextField), '1.42');
      await tester.ensureVisible(find.text('Use this width'));
      await tester.tap(find.text('Use this width'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Change the width'), findsNothing);

      await tester.pageBack();
      await tester.pump(_transition);
      expect(results, isEmpty, reason: 'leaving would delete what is being saved');
      expect(find.byType(AlertDialog), findsNothing);

      holding.complete();
      await tester.pump();
      await tester.pump(_transition);
      expect(results, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('going back', () {
    testWidgets('asks first when it would lose a photograph', (tester) async {
      final results = await openPage(tester, (_) async {}, discardsPhotograph: true);

      await tester.pageBack();
      await tester.pump(_transition);

      expect(find.text('Leave without a width?'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('asks nothing when it would not', (tester) async {
      final results = await openPage(tester, (_) async {});

      await tester.pageBack();
      await tester.pump();
      await tester.pump(_transition);

      expect(find.byType(AlertDialog), findsNothing);
      expect(results, [null]);
    });
  });
}
