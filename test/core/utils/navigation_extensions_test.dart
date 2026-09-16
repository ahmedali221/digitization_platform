import 'package:digitization_platform/core/utils/navigation_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression test for a go_router quirk that broke [PopToPathExtension]:
/// `RouteMatchList.push` carries the *base* list's `uri` field forward
/// unchanged (see go_router's own `RouteMatchList.copyWith`), so after a
/// chain of `context.push()` calls `currentConfiguration.uri.path` stays
/// pinned at whichever location the stack started from — it never reflects
/// the actual current page. `popToPath` used to compare against that field,
/// so it never found its target and popped all the way back to the app
/// root instead of stopping partway up the stack.
void main() {
  testWidgets(
    'popToPath stops at the target page instead of popping to the app root',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/sites',
        routes: [
          GoRoute(path: '/sites', builder: (c, s) => const _Page('sites')),
          GoRoute(
            path: '/sites/:siteId/buildings',
            builder: (c, s) => const _Page('buildings'),
          ),
          GoRoute(
            path: '/sites/:siteId/buildings/:buildingId/floors',
            builder: (c, s) => const _Page('floors-list'),
          ),
          GoRoute(
            path: '/sites/:siteId/buildings/:buildingId/floors/:floorId',
            builder: (c, s) => const _Page('floor-walls'),
          ),
          GoRoute(
            path:
                '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId',
            builder: (c, s) => const _Page('wall-detail'),
          ),
          GoRoute(
            path:
                '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/grid-capture',
            builder: (c, s) => const _Page('grid-capture'),
          ),
          GoRoute(
            path:
                '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/camera',
            builder: (c, s) => const _Page('camera'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Mirrors the real drill-down flow: every hop is a `push`, exactly
      // like FloorsListPage/FloorWallsPage/WallDetailPage/GridCapturePage.
      const floorWallsPath = '/sites/s1/buildings/b1/floors/f1';
      router.push('/sites/s1/buildings');
      await tester.pumpAndSettle();
      router.push('/sites/s1/buildings/b1/floors');
      await tester.pumpAndSettle();
      router.push(floorWallsPath);
      await tester.pumpAndSettle();
      router.push('$floorWallsPath/walls/w1');
      await tester.pumpAndSettle();
      router.push('$floorWallsPath/walls/w1/grid-capture');
      await tester.pumpAndSettle();
      router.push('$floorWallsPath/walls/w1/camera?cell=3');
      await tester.pumpAndSettle();

      expect(find.text('camera'), findsOneWidget);

      tester.element(find.text('camera')).popToPath(floorWallsPath);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
        floorWallsPath,
      );
      expect(find.text('floor-walls'), findsOneWidget);
      expect(find.text('camera'), findsNothing);
      expect(find.text('sites'), findsNothing);
    },
  );
}

class _Page extends StatelessWidget {
  const _Page(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}
