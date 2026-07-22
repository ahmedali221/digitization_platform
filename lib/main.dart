import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  runApp(const WallBaseApp());
}
