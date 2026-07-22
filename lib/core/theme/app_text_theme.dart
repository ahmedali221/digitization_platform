import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale from DESIGN_SYSTEM.md §3.
///
/// Uses `google_fonts`' runtime fetch for now — DESIGN_SYSTEM.md calls for
/// bundling Figtree as a local asset so offline first-launch never blocks on
/// a font fetch; swap to `GoogleFonts.figtree(...)` -> bundled `TextStyle`
/// once the font asset is added to the project (tracked in DESIGN_SYSTEM.md §11).
TextTheme buildAppTextTheme(Color onSurface) {
  final base = GoogleFonts.figtreeTextTheme();
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: onSurface,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
  );
}
