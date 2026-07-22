// Smoke test for the app shell. The previous version of this file tested the
// default Flutter counter demo, which main.dart no longer contains — it now
// bootstraps DI and the WallBase app instead.

import 'package:flutter_test/flutter_test.dart';

import 'package:digitization_platform/app.dart';
import 'package:digitization_platform/core/di/injection_container.dart';
import 'package:digitization_platform/core/router/app_router.dart';
import 'package:digitization_platform/features/map_navigation/presentation/widgets/shape_canvas.dart';

void main() {
  testWidgets('site navigation includes buildings before floors and walls', (
    WidgetTester tester,
  ) async {
    setupDependencies();

    await tester.pumpWidget(const WallBaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Sites'), findsOneWidget);

    await tester.tap(find.text('Saqqara North Necropolis'));
    await tester.pumpAndSettle();

    expect(find.text('Saqqara North Necropolis'), findsOneWidget);
    expect(find.byType(ShapeCanvas), findsOneWidget);

    appRouter.go('/sites/s1/buildings/b1/floors');
    await tester.pumpAndSettle();

    expect(find.text('Mastaba A'), findsOneWidget);
    expect(find.byType(ShapeCanvas), findsOneWidget);
    expect(find.text('No floors yet for this building.'), findsNothing);

    appRouter.go('/sites/s1/buildings/b1/floors/f1');
    await tester.pumpAndSettle();

    expect(find.text('Ground Floor'), findsWidgets);
    expect(find.text('North face'), findsOneWidget);
  });
}
