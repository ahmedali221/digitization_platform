/// Sizing for the capture screens' landscape layout, where the controls move
/// from under the viewfinder into a rail beside it.
abstract final class CameraMetrics {
  /// Share of the screen's width the rail takes, before [railMinWidth] and
  /// [railMaxWidth] bound it: wide enough for "Review (12/12)", narrow enough
  /// to leave the viewfinder most of a phone held sideways.
  static const double railWidthFraction = 0.28;
  static const double railMinWidth = 184;
  static const double railMaxWidth = 320;
}
