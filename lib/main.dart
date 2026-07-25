import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/background/sync_background_task.dart';
import 'core/di/injection_container.dart';
import 'core/storage/hive_boxes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await registerAdaptersAndOpenBoxes();
  setupDependencies();
  await seedInitialSession();
  wireForegroundSyncOnReconnect();
  await initializeSyncBackgroundTask();
  runApp(const WallBaseApp());
}
