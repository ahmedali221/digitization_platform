import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/grid_capture/data/datasources/capture_session_local_data_source.dart';
import '../../features/grid_capture/data/datasources/grid_capture_local_data_source.dart';
import '../../features/grid_capture/data/repositories/grid_capture_repository_impl.dart';
import '../../features/grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../features/map_navigation/data/repositories/map_geometry_repository_impl.dart';
import '../../features/map_navigation/domain/repositories/map_geometry_repository.dart';
import '../../features/site_sync/domain/services/site_download_service.dart';
import '../../features/sync_queue/data/datasources/sync_queue_local_data_source.dart';
import '../../features/sync_queue/data/datasources/sync_remote_data_source.dart';
import '../../features/sync_queue/data/repositories/sync_queue_repository_impl.dart';
import '../../features/sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../features/sync_queue/domain/repositories/sync_queue_repository.dart';
import '../../features/sync_queue/domain/services/sync_queue_runner.dart';
import '../../features/unassigned_walls/data/repositories/fake_unassigned_wall_repository.dart';
import '../../features/unassigned_walls/domain/repositories/unassigned_wall_repository.dart';
import '../data/datasources/site_local_data_source.dart';
import '../data/datasources/site_remote_data_source.dart';
import '../data/repositories/site_repository_impl.dart';
import '../domain/repositories/site_repository.dart';
import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../network/connectivity_observer.dart';
import '../network/file_downloader.dart';
import '../storage/device_id_provider.dart';
import '../storage/directory_manager.dart';
import '../storage/secure_token_storage.dart';

/// Shorthand for [GetIt.instance], kept as a top-level constant so feature
/// pages can resolve dependencies via either `sl<T>()` or
/// `GetIt.instance<T>()` — both names resolve to the exact same registry.
final GetIt sl = GetIt.instance;

/// Registers the real local-first data layer (Hive + Dio) behind the same
/// abstract repository contracts the UI was already built against. Only
/// `UnassignedWallRepository` still resolves to its fake — Phase 5's
/// local_id server-side resolution is explicitly out of scope for now.
void setupDependencies() {
  if (GetIt.instance.isRegistered<SiteRepository>()) return;

  GetIt.instance.registerLazySingleton<SecureTokenStorage>(
    () => SecureTokenStorage(),
  );
  GetIt.instance.registerLazySingleton<DirectoryManager>(
    () => DirectoryManager(),
  );
  GetIt.instance.registerLazySingleton<DeviceIdProvider>(
    () => DeviceIdProvider(),
  );
  GetIt.instance.registerLazySingleton<ConnectivityObserver>(
    () => ConnectivityObserver(),
  );

  GetIt.instance.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(GetIt.instance<SecureTokenStorage>()),
  );
  GetIt.instance.registerLazySingleton<Dio>(
    () => buildApiClient(GetIt.instance<AuthInterceptor>()),
  );

  GetIt.instance.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(GetIt.instance<Dio>()),
  );
  GetIt.instance.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: GetIt.instance<AuthRemoteDataSource>(),
      tokenStorage: GetIt.instance<SecureTokenStorage>(),
    ),
  );

  GetIt.instance.registerLazySingleton<SiteLocalDataSource>(
    () => SiteLocalDataSource(),
  );
  GetIt.instance.registerLazySingleton<SiteRemoteDataSource>(
    () => SiteRemoteDataSource(GetIt.instance<Dio>()),
  );
  GetIt.instance.registerLazySingleton<SiteDownloadService>(
    () => SiteDownloadService(
      remote: GetIt.instance<SiteRemoteDataSource>(),
      local: GetIt.instance<SiteLocalDataSource>(),
      downloader: FileDownloader(GetIt.instance<Dio>()),
      directoryManager: GetIt.instance<DirectoryManager>(),
      dio: GetIt.instance<Dio>(),
    ),
  );
  GetIt.instance.registerLazySingleton<SiteRepository>(
    () => SiteRepositoryImpl(
      local: GetIt.instance<SiteLocalDataSource>(),
      remote: GetIt.instance<SiteRemoteDataSource>(),
      downloadService: GetIt.instance<SiteDownloadService>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );
  GetIt.instance.registerLazySingleton<MapGeometryRepository>(
    () => MapGeometryRepositoryImpl(
      local: GetIt.instance<SiteLocalDataSource>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );

  // Sync queue registered before grid_capture: GridCaptureRepositoryImpl
  // depends on SyncEnqueuer to hand off finished/paused capture rounds.
  GetIt.instance.registerLazySingleton<SyncQueueLocalDataSource>(
    () => SyncQueueLocalDataSource(),
  );
  GetIt.instance.registerLazySingleton<SyncRemoteDataSource>(
    () => SyncRemoteDataSource(GetIt.instance<Dio>()),
  );
  GetIt.instance.registerLazySingleton<CaptureSessionLocalDataSource>(
    () => CaptureSessionLocalDataSource(),
  );
  GetIt.instance.registerLazySingleton<SyncQueueRunner>(
    () => SyncQueueRunner(
      queueLocal: GetIt.instance<SyncQueueLocalDataSource>(),
      sessionLocal: GetIt.instance<CaptureSessionLocalDataSource>(),
      remote: GetIt.instance<SyncRemoteDataSource>(),
      deviceIdProvider: GetIt.instance<DeviceIdProvider>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );
  GetIt.instance.registerLazySingleton<SyncQueueRepositoryImpl>(
    () => SyncQueueRepositoryImpl(
      GetIt.instance<SyncQueueLocalDataSource>(),
      GetIt.instance<SyncQueueRunner>(),
    ),
  );
  GetIt.instance.registerLazySingleton<SyncQueueRepository>(
    () => GetIt.instance<SyncQueueRepositoryImpl>(),
  );
  GetIt.instance.registerLazySingleton<SyncEnqueuer>(
    () => GetIt.instance<SyncQueueRepositoryImpl>(),
  );

  GetIt.instance.registerLazySingleton<GridCaptureLocalDataSource>(
    () => GridCaptureLocalDataSource(
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );
  GetIt.instance.registerLazySingleton<GridCaptureRepository>(
    () => GridCaptureRepositoryImpl(
      siteRepository: GetIt.instance<SiteRepository>(),
      sessionLocal: GetIt.instance<CaptureSessionLocalDataSource>(),
      fileLocal: GetIt.instance<GridCaptureLocalDataSource>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
      syncEnqueuer: GetIt.instance<SyncEnqueuer>(),
    ),
  );

  GetIt.instance.registerLazySingleton<UnassignedWallRepository>(
    () => FakeUnassignedWallRepository(),
  );
}

/// Seeds `isLoggedInNotifier` from whatever session is already on disk, so
/// the router's very first redirect decision (before first frame) is
/// already correct — called once at boot, after [setupDependencies].
Future<void> seedInitialSession() async {
  await GetIt.instance<AuthRepository>().hasValidSession();
}

/// Drains the sync queue immediately in the foreground whenever
/// connectivity returns, in addition to the periodic background task —
/// this is what makes reconnecting while the app is open feel immediate
/// rather than waiting for the next 15-minute background tick.
void wireForegroundSyncOnReconnect() {
  GetIt.instance<ConnectivityObserver>().onConnectivityChanged.listen((
    connected,
  ) {
    if (connected) {
      GetIt.instance<SyncQueueRunner>().drainAll();
    }
  });
}
