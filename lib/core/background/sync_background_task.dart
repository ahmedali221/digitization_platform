import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/sync_queue/domain/services/sync_queue_runner.dart';
import '../di/injection_container.dart';
import '../storage/hive_boxes.dart';

const String syncTaskUniqueName = 'wallbase-sync-queue-drain';
const String syncTaskName = 'sync-queue-drain';

/// Entry point workmanager invokes in its own background isolate — that
/// isolate shares no state with the main isolate's `GetIt`/Hive instances,
/// so everything is re-initialized here from scratch, exactly as it is at
/// app boot (`main.dart`).
@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await Hive.initFlutter();
    await registerAdaptersAndOpenBoxes();
    setupDependencies();
    await sl<SyncQueueRunner>().drainAll();
    return true;
  });
}

/// Registers the periodic drain. Requires the platform-side workmanager
/// setup (custom Android Application class registering
/// [syncCallbackDispatcher] / iOS Background Fetch capability) to actually
/// fire in the background — this call alone only handles the Dart side.
Future<void> initializeSyncBackgroundTask() async {
  await Workmanager().initialize(syncCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    syncTaskUniqueName,
    syncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
