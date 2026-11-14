import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/follow_up/presentation/pages/follow_up_page.dart';
import '../../features/grid_capture/presentation/pages/camera_capture_page.dart';
import '../../features/grid_capture/presentation/pages/coverage_review_page.dart';
import '../../features/grid_capture/presentation/pages/grid_capture_page.dart';
import '../../features/grid_capture/presentation/pages/grid_init_page.dart';
import '../../features/grid_capture/presentation/pages/grid_reshape_page.dart';
import '../../features/map_navigation/presentation/pages/add_item_page.dart';
import '../../features/map_navigation/presentation/pages/buildings_list_page.dart';
import '../../features/map_navigation/presentation/pages/floor_walls_page.dart';
import '../../features/map_navigation/presentation/pages/floors_list_page.dart';
import '../../features/map_navigation/presentation/pages/wall_detail_page.dart';
import '../../features/object_capture/presentation/object_capture_routes.dart';
import '../../features/object_capture/presentation/pages/capture_mode_page.dart';
import '../../features/object_capture/presentation/pages/free_capture_page.dart';
import '../../features/object_capture/presentation/pages/scan_capture_page.dart';
import '../../features/object_capture/presentation/pages/scan_status_page.dart';
import '../../features/object_capture/presentation/pages/organised_capture_page.dart';
import '../../features/site_sync/presentation/pages/sites_list_page.dart';
import '../../features/sync_queue/presentation/pages/sync_queue_page.dart';
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
      path: '/sites/:siteId/buildings/:buildingId/floors/:floorId/add-item',
      builder: (context, state) => AddItemPage(
        siteId: state.pathParameters['siteId']!,
        buildingId: state.pathParameters['buildingId']!,
        floorId: state.pathParameters['floorId']!,
        initialHallName: state.uri.queryParameters['hall'],
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
    GoRoute(
      path: '/sites/:siteId/follow-up',
      builder: (context, state) =>
          FollowUpPage(siteId: state.pathParameters['siteId']!),
    ),
    GoRoute(
      path: '$_wallPath/${ObjectCaptureRoutes.modesSegment}',
      builder: (context, state) =>
          CaptureModePage(routes: _objectCaptureRoutes(state)),
    ),
    GoRoute(
      path:
          '$_wallPath/${ObjectCaptureRoutes.modesSegment}/'
          '${ObjectCaptureRoutes.organisedSegment}',
      builder: (context, state) =>
          OrganisedCapturePage(routes: _objectCaptureRoutes(state)),
    ),
    GoRoute(
      path:
          '$_wallPath/${ObjectCaptureRoutes.modesSegment}/'
          '${ObjectCaptureRoutes.freeSegment}',
      builder: (context, state) =>
          FreeCapturePage(routes: _objectCaptureRoutes(state)),
    ),
    GoRoute(
      path:
          '$_wallPath/${ObjectCaptureRoutes.modesSegment}/'
          '${ObjectCaptureRoutes.scanSegment}',
      builder: (context, state) =>
          ScanCapturePage(routes: _objectCaptureRoutes(state)),
    ),
    GoRoute(
      path:
          '$_wallPath/${ObjectCaptureRoutes.modesSegment}/'
          '${ObjectCaptureRoutes.scanStatusSegment}',
      builder: (context, state) =>
          ScanStatusPage(routes: _objectCaptureRoutes(state)),
    ),
    GoRoute(path: '/sync', builder: (context, state) => const SyncQueuePage()),
  ],
);

const _wallPath =
    '/sites/:siteId/buildings/:buildingId/floors/:floorId/walls/:wallId';

ObjectCaptureRoutes _objectCaptureRoutes(GoRouterState state) {
  return ObjectCaptureRoutes(
    siteId: state.pathParameters['siteId']!,
    buildingId: state.pathParameters['buildingId']!,
    floorId: state.pathParameters['floorId']!,
    wallId: state.pathParameters['wallId']!,
  );
}
