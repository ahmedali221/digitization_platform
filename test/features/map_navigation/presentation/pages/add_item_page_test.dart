import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/core/domain/repositories/site_repository.dart';
import 'package:digitization_platform/features/map_navigation/presentation/pages/add_item_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

void main() {
  // The fake's first site, a building of it, and a floor of that building.
  const floorPath = '/sites/s1/buildings/b2/floors/f2';
  const wallPath = '$floorPath/walls/:wallId';

  late FakeSiteRepository repository;
  late GoRouter router;

  /// The app's own paths, with a labelled placeholder where each real screen
  /// would be: what matters here is which screen the form leads to, and what
  /// is underneath it.
  GoRouter buildRouter() {
    Widget placeholder(String label) => Scaffold(body: Text(label));

    return GoRouter(
      initialLocation: floorPath,
      routes: [
        GoRoute(path: floorPath, builder: (_, _) => placeholder('FLOOR')),
        GoRoute(
          path: '$floorPath/add-item',
          builder: (_, _) =>
              const AddItemPage(siteId: 's1', buildingId: 'b2', floorId: 'f2'),
        ),
        GoRoute(
          path: wallPath,
          builder: (_, state) =>
              placeholder('ITEM ${state.pathParameters['wallId']}'),
        ),
        GoRoute(
          path: '$wallPath/grid-init',
          builder: (_, _) => placeholder('GRID INIT'),
        ),
        GoRoute(
          path: '$wallPath/object-capture',
          builder: (_, _) => placeholder('OBJECT CAPTURE'),
        ),
      ],
    );
  }

  setUp(() async {
    await GetIt.instance.reset();
    repository = FakeSiteRepository();
    GetIt.instance.registerSingleton<SiteRepository>(repository);
    router = buildRouter();
  });

  Future<void> openForm(WidgetTester tester) async {
    // Tall enough for the whole form: the save button must be on screen to tap.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('$floorPath/add-item');
    await tester.pumpAndSettle();
  }

  Future<void> saveAs(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField).first, name);
    await tester.tap(find.text('Save and capture'));
    await tester.pumpAndSettle();
  }

  WallEntity addedItem() =>
      repository.findFloor('f2')!.walls.firstWhere((wall) => wall.isLocal);

  Future<void> goBack(WidgetTester tester) async {
    router.pop();
    await tester.pumpAndSettle();
  }

  testWidgets('saving a wall opens its grid, over its page, over the floor', (
    tester,
  ) async {
    await openForm(tester);

    await saveAs(tester, 'North face');

    expect(find.text('GRID INIT'), findsOneWidget);

    await goBack(tester);
    expect(find.text('ITEM ${addedItem().id}'), findsOneWidget);

    await goBack(tester);
    expect(find.text('FLOOR'), findsOneWidget, reason: 'the form is gone');
    expect(router.canPop(), isFalse);
  });

  testWidgets('saving a statue opens object capture instead', (tester) async {
    await openForm(tester);

    await tester.tap(find.text('Statue'));
    await tester.pumpAndSettle();
    await saveAs(tester, 'Seated scribe');

    expect(find.text('OBJECT CAPTURE'), findsOneWidget);
    expect(addedItem().name, 'Seated scribe');

    await goBack(tester);
    expect(find.text('ITEM ${addedItem().id}'), findsOneWidget);
  });

  testWidgets('an object is asked for what its label says; a wall is not', (
    tester,
  ) async {
    await openForm(tester);

    expect(find.text('INVENTORY NUMBER'), findsNothing);

    await tester.tap(find.text('Statue'));
    await tester.pumpAndSettle();

    expect(find.text('INVENTORY NUMBER'), findsOneWidget);
    expect(find.text('MATERIAL'), findsOneWidget);
  });

  testWidgets('saving without a name stays on the form and says why', (
    tester,
  ) async {
    await openForm(tester);

    await tester.tap(find.text('Save and capture'));
    await tester.pumpAndSettle();

    expect(find.text('A name is required'), findsOneWidget);
    expect(find.text('GRID INIT'), findsNothing);
    expect(
      repository.findFloor('f2')!.walls.any((wall) => wall.isLocal),
      isFalse,
    );
  });
}
