import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/follow_up/data/datasources/follow_up_local_data_source.dart';
import '../../features/follow_up/data/datasources/follow_up_remote_data_source.dart';
import '../../features/follow_up/data/repositories/follow_up_repository_impl.dart';
import '../../features/follow_up/domain/repositories/follow_up_repository.dart';
import '../../features/follow_up/domain/repositories/new_target_repository.dart';
import '../../features/follow_up/domain/services/follow_up_upload_runner.dart';
import '../camera/camera_preferences_local_data_source.dart';
import '../../features/grid_capture/data/datasources/capture_session_local_data_source.dart';
import '../../features/grid_capture/data/datasources/grid_capture_local_data_source.dart';
import '../../features/grid_capture/data/repositories/grid_capture_repository_impl.dart';
import '../../features/grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../features/grid_capture/domain/services/capture_analyzer_isolate.dart';
import '../../features/grid_capture/domain/services/capture_recovery_service.dart';
import '../../features/grid_capture/domain/services/cell_quality_analyzer.dart';
import '../../features/map_navigation/data/repositories/map_geometry_repository_impl.dart';
import '../../features/map_navigation/domain/repositories/map_geometry_repository.dart';
import '../../features/object_capture/data/datasources/object_capture_local_data_source.dart';
import '../../features/object_capture/data/datasources/object_capture_remote_data_source.dart';
import '../../features/object_capture/data/repositories/object_capture_repository_impl.dart';
import '../../features/object_capture/data/uploaders/object_photos_uploader.dart';
import '../../features/object_capture/data/datasources/device_camera_motion_source.dart';
import '../../features/object_capture/data/datasources/object_scan_local_data_source.dart';
import '../../features/object_capture/data/datasources/object_scan_remote_data_source.dart';
import '../../features/object_capture/data/repositories/object_scan_repository_impl.dart';
import '../../features/object_capture/data/uploaders/object_scan_uploader.dart';
import '../../features/object_capture/domain/repositories/object_capture_repository.dart';
import '../../features/object_capture/domain/repositories/object_scan_repository.dart';
import '../../features/object_capture/domain/services/camera_motion_source.dart';
import '../../features/site_backup/domain/services/site_backup_service.dart';
import '../../features/site_sync/domain/services/site_download_service.dart';
import '../../features/sync_queue/data/datasources/sync_queue_local_data_source.dart';
import '../../features/sync_queue/data/datasources/sync_remote_data_source.dart';
import '../../features/sync_queue/data/repositories/sync_queue_repository_impl.dart';
import '../../features/sync_queue/data/uploaders/grid_session_uploader.dart';
import '../../features/sync_queue/domain/entities/sync_item_kind.dart';
import '../../features/sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../features/sync_queue/domain/repositories/sync_queue_repository.dart';
import '../../features/sync_queue/domain/services/field_item_registrar.dart';
import '../../features/sync_queue/domain/services/sync_queue_runner.dart';
import '../data/datasources/site_local_data_source.dart';
import '../data/datasources/site_remote_data_source.dart';
import '../data/repositories/site_repository_impl.dart';
import '../domain/repositories/site_repository.dart';
import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../network/connectivity_observer.dart';
import '../network/file_downloader.dart';
import '../network/session_notifier.dart';
import '../storage/device_id_provider.dart';
import '../storage/directory_manager.dart';
import '../storage/gallery_backup_service.dart';
import '../storage/secure_token_storage.dart';

/// Shorthand for [GetIt.instance], kept as a top-level constant so feature
/// pages can resolve dependencies via either `sl<T>()` or
/// `GetIt.instance<T>()` — both names resolve to the exact same registry.
final GetIt sl = GetIt.instance;

/// Registers the real local-first data layer (Hive + Dio) behind the same
/// abstract repository contracts the UI was already built against.
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
  GetIt.instance.registerLazySingleton<GalleryBackupService>(
    () => GalleryBackupService(),
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
      deviceIdProvider: GetIt.instance<DeviceIdProvider>(),
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
  GetIt.instance.registerLazySingleton<ObjectCaptureLocalDataSource>(
    () => ObjectCaptureLocalDataSource(
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );
  GetIt.instance.registerLazySingleton<ObjectScanLocalDataSource>(
    () => ObjectScanLocalDataSource(
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
  );
  GetIt.instance.registerLazySingleton<ObjectScanRemoteDataSource>(
    () => ObjectScanRemoteDataSource(GetIt.instance<Dio>()),
  );
  GetIt.instance.registerLazySingleton<FieldItemRegistrar>(
    () => FieldItemRegistrar(
      siteLocal: GetIt.instance<SiteLocalDataSource>(),
      remote: GetIt.instance<SyncRemoteDataSource>(),
      deviceIdProvider: GetIt.instance<DeviceIdProvider>(),
    ),
  );
  // One uploader per kind of capture: a new kind is a new entry here, not a
  // new branch in the runner.
  GetIt.instance.registerLazySingleton<SyncQueueRunner>(
    () => SyncQueueRunner(
      queueLocal: GetIt.instance<SyncQueueLocalDataSource>(),
      registrar: GetIt.instance<FieldItemRegistrar>(),
      uploaders: {
        SyncItemKind.gridSession: GridSessionUploader(
          sessionLocal: GetIt.instance<CaptureSessionLocalDataSource>(),
          remote: GetIt.instance<SyncRemoteDataSource>(),
          deviceIdProvider: GetIt.instance<DeviceIdProvider>(),
          directoryManager: GetIt.instance<DirectoryManager>(),
          galleryBackup: GetIt.instance<GalleryBackupService>(),
        ),
        SyncItemKind.objectPhotos: ObjectPhotosUploader(
          local: GetIt.instance<ObjectCaptureLocalDataSource>(),
          remote: ObjectCaptureRemoteDataSource(GetIt.instance<Dio>()),
          directoryManager: GetIt.instance<DirectoryManager>(),
        ),
        SyncItemKind.objectScan: ObjectScanUploader(
          local: GetIt.instance<ObjectScanLocalDataSource>(),
          remote: GetIt.instance<ObjectScanRemoteDataSource>(),
          directoryManager: GetIt.instance<DirectoryManager>(),
        ),
      },
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
  GetIt.instance.registerLazySingleton<CameraPreferencesLocalDataSource>(
    () => CameraPreferencesLocalDataSource(),
  );
  // One worker isolate shared by every CaptureSessionCubit. SIFT must never
  // run on the main isolate: see CaptureAnalyzerIsolate.
  GetIt.instance.registerLazySingleton<CellQualityAnalyzer>(
    () => CaptureAnalyzerIsolate(),
  );
  GetIt.instance.registerLazySingleton<GridCaptureRepository>(
    () => GridCaptureRepositoryImpl(
      siteRepository: GetIt.instance<SiteRepository>(),
      sessionLocal: GetIt.instance<CaptureSessionLocalDataSource>(),
      fileLocal: GetIt.instance<GridCaptureLocalDataSource>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
      syncEnqueuer: GetIt.instance<SyncEnqueuer>(),
      galleryBackup: GetIt.instance<GalleryBackupService>(),
    ),
  );
  GetIt.instance.registerLazySingleton<CaptureRecoveryService>(
    () => CaptureRecoveryService(
      galleryBackup: GetIt.instance<GalleryBackupService>(),
      sessionLocal: GetIt.instance<CaptureSessionLocalDataSource>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
      syncEnqueuer: GetIt.instance<SyncEnqueuer>(),
    ),
  );

  GetIt.instance.registerLazySingleton<ObjectCaptureRepository>(
    () => ObjectCaptureRepositoryImpl(
      siteRepository: GetIt.instance<SiteRepository>(),
      local: GetIt.instance<ObjectCaptureLocalDataSource>(),
      syncEnqueuer: GetIt.instance<SyncEnqueuer>(),
    ),
  );

  GetIt.instance.registerLazySingleton<ObjectScanRepository>(
    () => ObjectScanRepositoryImpl(
      siteRepository: GetIt.instance<SiteRepository>(),
      local: GetIt.instance<ObjectScanLocalDataSource>(),
      remote: GetIt.instance<ObjectScanRemoteDataSource>(),
      syncEnqueuer: GetIt.instance<SyncEnqueuer>(),
    ),
  );
  GetIt.instance.registerLazySingleton<CameraMotionSource>(
    () => const DeviceCameraMotionSource(),
  );

  GetIt.instance.registerLazySingleton<FollowUpLocalDataSource>(
    () => FollowUpLocalDataSource(),
  );
  GetIt.instance.registerLazySingleton<FollowUpRemoteDataSource>(
    () => FollowUpRemoteDataSource(GetIt.instance<Dio>()),
  );
  GetIt.instance.registerLazySingleton<FollowUpUploadRunner>(
    () => FollowUpUploadRunner(
      local: GetIt.instance<FollowUpLocalDataSource>(),
      remote: GetIt.instance<FollowUpRemoteDataSource>(),
      resolveFile: GetIt.instance<DirectoryManager>().resolveExistingFile,
      stitchedPreviewPath: (record) async =>
          FollowUpRepositoryImpl.stitchedPreviewPath(
            await GetIt.instance<DirectoryManager>().followUpDir(
              record.siteId,
              FollowUpRepositoryImpl.previewsFolder,
            ),
            record.token,
          ),
    ),
  );
  GetIt.instance.registerLazySingleton<FollowUpRepositoryImpl>(
    () => FollowUpRepositoryImpl(
      local: GetIt.instance<FollowUpLocalDataSource>(),
      remote: GetIt.instance<FollowUpRemoteDataSource>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
      runner: GetIt.instance<FollowUpUploadRunner>(),
    ),
  );
  GetIt.instance.registerLazySingleton<FollowUpRepository>(
    () => GetIt.instance<FollowUpRepositoryImpl>(),
  );
  GetIt.instance.registerLazySingleton<NewTargetRepository>(
    () => GetIt.instance<FollowUpRepositoryImpl>(),
  );

  GetIt.instance.registerLazySingleton<SiteBackupService>(
    () => SiteBackupService(
      siteRepository: GetIt.instance<SiteRepository>(),
      gridCaptureRepository: GetIt.instance<GridCaptureRepository>(),
      objectCaptureRepository: GetIt.instance<ObjectCaptureRepository>(),
      directoryManager: GetIt.instance<DirectoryManager>(),
    ),
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
      GetIt.instance<FollowUpUploadRunner>().drainAll();
    }
  });
}

/// Drains the sync queue every time a session becomes active — a fresh
/// login, or [seedInitialSession] confirming a session already on disk at
/// boot. [SyncQueueRunner.drainAll] already skips anything already
/// `confirmed`, so this is a no-op when everything's already synced and an
/// immediate upload attempt when it isn't, rather than waiting for a
/// reconnect event or the next 15-minute background tick. Must be wired
/// before [seedInitialSession] runs so it's already listening for that
/// first transition.
void wireSyncOnLogin() {
  isLoggedInNotifier.addListener(() async {
    if (!isLoggedInNotifier.value) return;
    // Recover anything the gallery still has a backup copy of but the local
    // `sessions` box doesn't (see CaptureRecoveryService) before draining,
    // so a session recovered from a reinstall gets uploaded in this same
    // pass rather than waiting for the next trigger.
    await GetIt.instance<CaptureRecoveryService>().recoverOrphanedWalls();
    await GetIt.instance<SyncQueueRunner>().drainAll();
    await GetIt.instance<FollowUpUploadRunner>().drainAll();
  });
}
