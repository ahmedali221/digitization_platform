import 'package:flutter/material.dart';

/// Brand seed and semantic roles beyond Material's ColorScheme defaults.
/// See DESIGN_SYSTEM.md §2.1 / §2.3.
abstract final class AppColors {
  /// Tailwind blue-700 — a shade darker than the `captured` status blue
  /// (#2563EB) so primary actions and the `captured` chip stay distinguishable
  /// when they sit side by side.
  static const seed = Color(0xFF1D4ED8);

  static const onSurfaceMuted = Color(0xFF6B7280);
  static const outlineSubtle = Color(0xFFE5E7EB);
  static const surfaceNeutral = Color(0xFFF9FAFB);
  static const iconMuted = Color(0xFF9CA3AF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondaryIcon = Color(0xFF374151);
  static const hoverSurface = Color(0xFFF1F2F4);

  static const successContainer = Color(0xFFD1FAE5);
  static const onSuccessContainer = Color(0xFF065F46);
  static const warningContainer = Color(0xFFFEF3C7);
  static const onWarningContainer = Color(0xFF92400E);
  static const dangerContainer = Color(0xFFFEE2E2);
  static const onDangerContainer = Color(0xFFB91C1C);

  static const offlineIndicatorBackground = hoverSurface;
  static const offlineIndicatorForeground = textSecondaryIcon;

  /// Camera capture screen background (Phase 3) — a dark, non-themed surface.
  static const cameraBackground = Color(0xFF14161A);
  static const cameraScrim = Color(0x8C000000);
}
