import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class WallBaseApp extends StatelessWidget {
  const WallBaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WallBase',
      theme: AppTheme.standard(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
