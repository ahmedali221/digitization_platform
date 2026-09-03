import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class NileLensApp extends StatelessWidget {
  const NileLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NileLens',
      theme: AppTheme.standard(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
