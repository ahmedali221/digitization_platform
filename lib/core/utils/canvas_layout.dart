import 'dart:ui' show Offset;

import '../domain/entities/canvas_shape.dart';

/// Auto-layout for canvas shapes when a bundle doesn't carry designer-placed
/// positions (mirrors the dashboard's own fallback —
/// `SitePackageBuilder::autoLayoutBuildingShapes`/`autoLayoutRooms`). Once a
/// real bundle supplies explicit shape coordinates, those take precedence and
/// this is only the fallback path.
abstract final class CanvasLayout {
  static const double cellWidth = 220;
  static const double cellHeight = 160;
  static const double padding = 24;
  static const int defaultColumns = 2;

  /// The canvas size that exactly fits [itemCount] shapes laid out by
  /// [rectFor].
  static CanvasSize sizeFor(int itemCount, {int columns = defaultColumns}) {
    if (itemCount == 0) {
      return const CanvasSize(
        width: cellWidth + padding * 2,
        height: cellHeight + padding * 2,
      );
    }
    final cols = itemCount < columns ? itemCount : columns;
    final rows = (itemCount / cols).ceil();
    return CanvasSize(
      width: cols * cellWidth + (cols + 1) * padding,
      height: rows * cellHeight + (rows + 1) * padding,
    );
  }

  /// Grid position for the item at [index] among [itemCount] total, matching
  /// the canvas returned by [sizeFor] for the same arguments.
  static RectShape rectFor(
    int index,
    int itemCount, {
    int columns = defaultColumns,
  }) {
    final cols = itemCount < columns ? itemCount : columns;
    final col = index % cols;
    final row = index ~/ cols;
    return RectShape(
      x: padding + col * (cellWidth + padding),
      y: padding + row * (cellHeight + padding),
      w: cellWidth,
      h: cellHeight,
    );
  }

  /// Distributes [wallCount] wall segments evenly around [room]'s perimeter,
  /// walking clockwise from the top-left corner.
  static List<WallLineShape> wallsAroundRoom(RectShape room, int wallCount) {
    if (wallCount <= 0) return const [];
    final perimeter = 2 * (room.w + room.h);
    final step = perimeter / wallCount;
    return List.generate(wallCount, (i) {
      final start = _pointOnPerimeter(room, i * step);
      final end = _pointOnPerimeter(room, (i + 1) * step);
      return WallLineShape(x1: start.dx, y1: start.dy, x2: end.dx, y2: end.dy);
    });
  }

  static Offset _pointOnPerimeter(RectShape r, double distance) {
    final perimeter = 2 * (r.w + r.h);
    final d = distance % perimeter;
    if (d <= r.w) return Offset(r.x + d, r.y); // top edge, left → right
    final afterTop = d - r.w;
    if (afterTop <= r.h) {
      return Offset(r.x + r.w, r.y + afterTop); // right edge, top → bottom
    }
    final afterRight = afterTop - r.h;
    if (afterRight <= r.w) {
      return Offset(
        r.x + r.w - afterRight,
        r.y + r.h,
      ); // bottom edge, right → left
    }
    final afterBottom = afterRight - r.w;
    return Offset(r.x, r.y + r.h - afterBottom); // left edge, bottom → top
  }
}
