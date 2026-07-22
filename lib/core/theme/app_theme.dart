import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

/// Standard (indoor/default) theme. The outdoor high-contrast variant is a
/// Phase 8 add-on (DESIGN_SYSTEM.md §2.4, §11) — not built yet.
class AppTheme {
  static ThemeData standard() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceNeutral,
      textTheme: buildAppTextTheme(AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: AppColors.outlineSubtle,
    );
  }
}
