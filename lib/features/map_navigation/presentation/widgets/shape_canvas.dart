import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/domain/entities/canvas_shape.dart';

typedef ShapeTapCallback = void Function(String shapeId);

/// A shape to paint on a [ShapeCanvas], pairing bundle geometry with the
/// visual/interaction properties the painter and hit-tester need. Kept
/// separate from the domain shapes in `core/domain/entities/canvas_shape.dart`
/// — those are pure geometry, this is a presentation-layer view model.
sealed class CanvasShape {
  const CanvasShape({required this.id, required this.color, this.label});

  final String id;
  final Color color;
  final String? label;
}

class CanvasRect extends CanvasShape {
  const CanvasRect({
    required super.id,
    required super.color,
    super.label,
    required this.rect,
  });

  final RectShape rect;
}

class CanvasLine extends CanvasShape {
  const CanvasLine({
    required super.id,
    required super.color,
    super.label,
    required this.line,
  });

  final WallLineShape line;
}

/// Renders any list of [CanvasShape]s on a fixed-size logical canvas
/// (FLUTTER_MOBILE_PLAN.md §2/§5's `CustomPainter` map renderer), with
/// pinch-zoom + pan and tap-to-shape hit-testing.
///
/// Set [interactive] to false for a small, non-scrollable diagram embedded in
/// already-scrollable content (e.g. a bottom sheet) — `InteractiveViewer`'s
/// pan gesture would otherwise fight the sheet's own scroll gesture.
class ShapeCanvas extends StatefulWidget {
  const ShapeCanvas({
    super.key,
    required this.canvasSize,
    required this.shapes,
    required this.onShapeTap,
    this.dimmedShapeIds = const {},
    this.interactive = true,
  });

  final CanvasSize canvasSize;
  final List<CanvasShape> shapes;
  final ShapeTapCallback onShapeTap;
  final Set<String> dimmedShapeIds;
  final bool interactive;

  @override
  State<ShapeCanvas> createState() => _ShapeCanvasState();
}

class _ShapeCanvasState extends State<ShapeCanvas> {
  final TransformationController _controller = TransformationController();
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fitToViewport(BoxConstraints constraints) {
    if (_fitted ||
        widget.canvasSize.width == 0 ||
        widget.canvasSize.height == 0) {
      return;
    }
    final scale = math
        .min(
          constraints.maxWidth / widget.canvasSize.width,
          constraints.maxHeight / widget.canvasSize.height,
        )
        .clamp(0.1, 1.0);
    _controller.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1);
    _fitted = true;
  }

  void _handleTap(Offset localPosition) {
    final hit = _hitTestShapes(widget.shapes, localPosition);
    if (hit != null) widget.onShapeTap(hit);
  }

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition),
      child: SizedBox(
        width: widget.canvasSize.width,
        height: widget.canvasSize.height,
        child: CustomPaint(
          painter: _ShapePainter(
            shapes: widget.shapes,
            dimmedShapeIds: widget.dimmedShapeIds,
          ),
        ),
      ),
    );

    if (!widget.interactive) {
      return FittedBox(fit: BoxFit.contain, child: content);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_fitted) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _fitToViewport(constraints),
          );
        }
        return InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: 0.15,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(120),
          child: content,
        );
      },
    );
  }
}

/// Lines take priority over rects at the same point (walls sit visually on
/// top of a room's fill), then rects, in reverse paint order (topmost drawn
/// shape wins).
String? _hitTestShapes(List<CanvasShape> shapes, Offset point) {
  for (final shape in shapes.reversed) {
    if (shape is CanvasLine && shape.line.isNear(point)) return shape.id;
  }
  for (final shape in shapes.reversed) {
    if (shape is CanvasRect && shape.rect.contains(point)) return shape.id;
  }
  return null;
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.shapes, required this.dimmedShapeIds});

  final List<CanvasShape> shapes;
  final Set<String> dimmedShapeIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in shapes) {
      final dimmed = dimmedShapeIds.contains(shape.id);
      switch (shape) {
        case CanvasRect(:final rect, :final color, :final label):
          _paintRect(canvas, rect, color, label, dimmed);
        case CanvasLine(:final line, :final color):
          _paintLine(canvas, line, color, dimmed);
      }
    }
  }

  void _paintRect(
    Canvas canvas,
    RectShape rect,
    Color color,
    String? label,
    bool dimmed,
  ) {
    final opacity = dimmed ? 0.25 : 1.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.x, rect.y, rect.w, rect.h),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.16 * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (label == null) return;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      ellipsis: '…',
      maxLines: 2,
    )..layout(maxWidth: rect.w - 16);
    painter.paint(canvas, Offset(rect.x + 8, rect.y + 8));
  }

  void _paintLine(Canvas canvas, WallLineShape line, Color color, bool dimmed) {
    canvas.drawLine(
      Offset(line.x1, line.y1),
      Offset(line.x2, line.y2),
      Paint()
        ..color = color.withValues(alpha: dimmed ? 0.25 : 1.0)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) => true;
}
