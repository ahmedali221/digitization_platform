import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/grid_capture/presentation/pages/camera_capture_page.dart';
import '../../features/grid_capture/presentation/pages/coverage_review_page.dart';
import '../../features/grid_capture/presentation/pages/grid_capture_page.dart';
import '../../features/grid_capture/presentation/pages/grid_init_page.dart';
import '../../features/grid_capture/presentation/pages/grid_reshape_page.dart';
import '../../features/map_navigation/presentation/pages/add_wall_page.dart';
import '../../features/map_navigation/presentation/pages/buildings_list_page.dart';
import '../../features/map_navigation/presentation/pages/floor_walls_page.dart';
import '../../features/map_navigation/presentation/pages/floors_list_page.dart';
import '../../features/map_navigation/presentation/pages/wall_detail_page.dart';
import '../../features/site_sync/presentation/pages/sites_list_page.dart';
import '../../features/sync_queue/presentation/pages/sync_queue_page.dart';
import '../../features/unassigned_walls/presentation/pages/unassigned_walls_page.dart';
import '../domain/repositories/site_repository.dart';
import '../network/session_notifier.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/sites',
  refreshListenable: isLoggedInNotifier,
  redirect: (context, state) {
    final loggedIn = isLoggedInNotifier.value;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/sites';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/sites', builder: (context, state) => const SitesListPage()),
    GoRoute(
      path: '/sites/:siteId/buildings',
      builder: (context, state) =>
          BuildingsListPage(siteId: state.pathParameters['siteId']!),
    ),
    GoRoute(
      path: '/sites/:siteId/buildings/:buildingId/floors',
      builder: (context, state) => FloorsListPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
      ),
    ),
    GoRoute(
      path: '/sites/:siteId/buildings/:buildingId/floors/:floorId',
      builder: (context, state) => FloorWallsPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
      ),
    ),
    GoRoute(
      path: '/sites/:siteId/buildings/:buildingId/floors/:floorId/add-wall',
      builder: (context, state) => AddWallPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
      ),
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId',
      builder: (context, state) => WallDetailPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
        wallId: state.pathParameters['wallId']!,
      ),
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/grid-init',
      builder: (context, state) {
        final floorId = state.pathParameters['floorId']!;
        final wallId = state.pathParameters['wallId']!;
        final wallName =
            GetIt.instance<SiteRepository>().findWall(floorId, wallId)?.name ??
            '';
        return GridInitPage(
          siteId: state.pathParameters['siteId']!,
          buildingId: state.pathParameters['buildingId']!,
          floorId: floorId,
          wallId: wallId,
          wallName: wallName,
        );
      },
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/grid-reshape',
      builder: (context, state) {
        final floorId = state.pathParameters['floorId']!;
        final wallId = state.pathParameters['wallId']!;
        final wallName =
            GetIt.instance<SiteRepository>().findWall(floorId, wallId)?.name ??
            '';
        return GridReshapePage(
          siteId: state.pathParameters['siteId']!,
          buildingId: state.pathParameters['buildingId']!,
          floorId: floorId,
          wallId: wallId,
          wallName: wallName,
        );
      },
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/grid-capture',
      builder: (context, state) => GridCapturePage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
        wallId: state.pathParameters['wallId']!,
      ),
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/camera',
      builder: (context, state) => CameraCapturePage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
        wallId: state.pathParameters['wallId']!,
      ),
    ),
    GoRoute(
      path:
          '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId/coverage-review',
      builder: (context, state) => CoverageReviewPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
        wallId: state.pathParameters['wallId']!,
      ),
    ),
    GoRoute(path: '/sync', builder: (context, state) => const SyncQueuePage()),
    GoRoute(
      path: '/unassigned',
      builder: (context, state) => const UnassignedWallsPage(),
    ),
  ],
);
