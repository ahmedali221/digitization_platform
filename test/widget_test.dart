// Smoke test for the app shell. The previous version of this file tested the
// default Flutter counter demo, which main.dart no longer contains — it now
// bootstraps DI and the WallBase app instead.
//
// This is a pure UI/navigation smoke test, so it registers the in-memory
// fake repository directly rather than calling the app's production
// `setupDependencies()` (which wires the real Hive/Dio-backed data layer —
// needing a device, network, and an authenticated session) and bypasses the
// login redirect, since auth isn't what this test is exercising.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:digitization_platform/app.dart';
import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/core/domain/repositories/site_repository.dart';
import 'package:digitization_platform/core/network/connectivity_observer.dart';
import 'package:digitization_platform/core/network/session_notifier.dart';
import 'package:digitization_platform/core/router/app_router.dart';
import 'package:digitization_platform/features/map_navigation/data/repositories/fake_map_geometry_repository.dart';
import 'package:digitization_platform/features/map_navigation/domain/repositories/map_geometry_repository.dart';
import 'package:digitization_platform/features/map_navigation/presentation/widgets/shape_canvas.dart';

void main() {
  testWidgets('site navigation includes buildings before floors and walls', (
    WidgetTester tester,
  ) async {
    await GetIt.instance.reset();
    GetIt.instance.registerLazySingleton<SiteRepository>(
      () => FakeSiteRepository(),
    );
    GetIt.instance.registerLazySingleton<ConnectivityObserver>(
      () => ConnectivityObserver(),
    );
    GetIt.instance.registerLazySingleton<MapGeometryRepository>(
      () => const FakeMapGeometryRepository(),
    );
    isLoggedInNotifier.value = true;

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
