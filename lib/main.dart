import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/background/sync_background_task.dart';
import 'core/di/injection_container.dart';
import 'core/storage/directory_manager.dart';
import 'core/storage/hive_boxes.dart';

// Flutter's global image cache defaults to 100MB — shared across every
// screen and every wall, not per-wall. A capture session downsamples
// thumbnails (~2MB decoded each at typical device pixel ratios), so the
// default caps out around ~50 distinct photos; past that, decoded bitmaps
// get evicted and re-decoded on every rebuild, which reads as the app
// "freezing" once a user's combined photo count across walls climbs into
// the hundreds. Raised to a budget sized for hundreds of thumbnails plus a
// couple of full-resolution single-photo previews at once.
const _imageCacheSizeBytes = 300 << 20; // 300MB

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = _imageCacheSizeBytes;
  await Hive.initFlutter();
  await registerAdaptersAndOpenBoxes();
  setupDependencies();
  await sl<DirectoryManager>().init();
  wireSyncOnLogin();
  await seedInitialSession();
  wireForegroundSyncOnReconnect();
  await initializeSyncBackgroundTask();
  runApp(const NileLensApp());
}
