/// Spacing values pulled directly from the design handoff prototype
/// (`WallBase Sites.dc.html`) for the site overview screen and its two
/// sheets. These specific pixel values don't land on the shared 4pt
/// `AppSpacing` scale (closest tokens: sm=8, md=12, lg=16, xl=24) — kept as a
/// small, local extension of the token set for this screen only, per
/// CLAUDE.md's DIP rule, rather than distorting the shared scale for one
/// screen's exact numbers.
abstract final class OverviewMetrics {
  static const double horizontalPadding = 20;
  static const double subtitleBottomGap = 14;
  static const double legendBottomGap = 18;
  static const double sheetTopPadding = 20;
  static const double wallSheetBottomPadding = 28;
}
