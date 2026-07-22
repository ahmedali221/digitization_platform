import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

/// A canvas's fixed drawing surface, in logical units — shapes on it are
/// authored/laid out in these units regardless of the device's actual
/// screen size (mirrors the bundle's `canvas{}` JSON: width/height/
/// background, FLUTTER_MOBILE_PLAN.md §2/§5).
class CanvasSize extends Equatable {
  const CanvasSize({
    required this.width,
    required this.height,
    this.backgroundImageUrl,
  });

  final double width;
  final double height;
  final String? backgroundImageUrl;

  @override
  List<Object?> get props => [width, height, backgroundImageUrl];
}

/// A tappable rectangle in canvas coordinates — a building, floor, or room
/// shape from the bundle's shape arrays.
class RectShape extends Equatable {
  const RectShape({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  bool contains(Offset point) =>
      point.dx >= x && point.dx <= x + w && point.dy >= y && point.dy <= y + h;

  @override
  List<Object?> get props => [x, y, w, h];
}

/// A tappable line segment in canvas coordinates — a wall drawn along its
/// room's edge. Hit-testing uses point-to-segment distance with a fixed
/// padding so thin wall strokes stay easy to tap on a touchscreen.
class WallLineShape extends Equatable {
  const WallLineShape({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  static const double _hitPadding = 14;

  bool isNear(Offset point) => _distanceToSegment(point) <= _hitPadding;

  double _distanceToSegment(Offset point) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return (point - Offset(x1, y1)).distance;

    final t = (((point.dx - x1) * dx + (point.dy - y1) * dy) / lengthSquared)
        .clamp(0.0, 1.0);
    final projection = Offset(x1 + t * dx, y1 + t * dy);
    return (point - projection).distance;
  }

  @override
  List<Object?> get props => [x1, y1, x2, y2];
}
