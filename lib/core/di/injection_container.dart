import 'package:get_it/get_it.dart';

import '../../features/grid_capture/data/datasources/grid_capture_local_data_source.dart';
import '../../features/grid_capture/data/repositories/fake_grid_capture_repository.dart';
import '../../features/grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../features/sync_queue/data/repositories/fake_sync_queue_repository.dart';
import '../../features/sync_queue/domain/repositories/sync_queue_repository.dart';
import '../../features/unassigned_walls/data/repositories/fake_unassigned_wall_repository.dart';
import '../../features/unassigned_walls/domain/repositories/unassigned_wall_repository.dart';
import '../data/repositories/fake_site_repository.dart';
import '../domain/repositories/site_repository.dart';

/// Shorthand for [GetIt.instance], kept as a top-level constant so feature
/// pages can resolve dependencies via either `sl<T>()` or
/// `GetIt.instance<T>()` — both names resolve to the exact same registry.
final GetIt sl = GetIt.instance;

/// Registers fake, in-memory repository implementations so the UI can be
/// built and verified against the design before the real Phase 0/1 data
/// layer (Hive boxes, Dio client) exists. Swapping a fake for its real
/// implementation later is a one-line change here — cubits depend only on
/// the abstract repository contracts (CLAUDE.md's DIP rule).
void setupDependencies() {
  if (GetIt.instance.isRegistered<SiteRepository>()) return;

  GetIt.instance.registerLazySingleton<SiteRepository>(
    () => FakeSiteRepository(),
  );
  GetIt.instance.registerLazySingleton<GridCaptureRepository>(
    () => FakeGridCaptureRepository(GetIt.instance<SiteRepository>()),
  );
  GetIt.instance.registerLazySingleton<GridCaptureLocalDataSource>(
    () => GridCaptureLocalDataSource(),
  );
  GetIt.instance.registerLazySingleton<SyncQueueRepository>(
    () => FakeSyncQueueRepository(),
  );
  GetIt.instance.registerLazySingleton<UnassignedWallRepository>(
    () => FakeUnassignedWallRepository(),
  );
}
