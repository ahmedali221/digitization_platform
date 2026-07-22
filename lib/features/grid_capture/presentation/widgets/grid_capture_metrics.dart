import 'package:flutter/material.dart';

/// Values pulled directly from the design handoff prototype
/// (`WallBase Sites.dc.html`) for the grid-init / grid-capture / camera /
/// coverage-review screens that don't land on the shared 4pt `AppSpacing`
/// scale or the existing `AppColors`/`kWallStatusMeta` token sets — kept as a
/// small, local extension of the token set for this feature only, per
/// CLAUDE.md's DIP rule, rather than distorting the shared scale or
/// inventing a shared-looking color that isn't actually reused elsewhere.
abstract final class GridCaptureMetrics {
  static const double horizontalPadding = 20;
  static const double gap = 10;
  static const double shutterBottomPadding = 28;

  /// "Has photos" cell tint — lighter than the captured-status blue used for
  /// the selected-cell background, no equivalent shared token.
  static const Color cellFilledBackground = Color(0xFFF1F5FF);

  /// Camera thumbnail-strip placeholder background — a camera-only dark
  /// neutral, no equivalent shared token.
  static const Color cameraThumbBackground = Color(0xFF2A2D33);
}
