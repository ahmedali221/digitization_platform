import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/domain/entities/canvas_shape.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

typedef ShapeTapCallback = void Function(String shapeId);

/// A shape to paint on a [ShapeCanvas], pairing bundle geometry with the
/// visual/interaction properties the painter and hit-tester need. Kept
/// separate from the domain shapes in `core/domain/entities/canvas_shape.dart`
/// — those are pure geometry, this is a presentation-layer view model.
sealed class CanvasShape {
  const CanvasShape({
    required this.id,
    required this.color,
    this.label,
    this.selectable = true,
  });

  final String id;
  final Color color;
  final String? label;
  final bool selectable;
}

class CanvasRect extends CanvasShape {
  const CanvasRect({
    required super.id,
    required super.color,
    super.label,
    super.selectable,
    required this.rect,
  });

  final RectShape rect;
}

class CanvasLine extends CanvasShape {
  const CanvasLine({
    required super.id,
    required super.color,
    super.label,
    super.selectable,
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
    this.fullscreenTitle = 'Map',
    this.allowFullscreen = true,
    this.showZoomControls = false,
  });

  final CanvasSize canvasSize;
  final List<CanvasShape> shapes;
  final ShapeTapCallback onShapeTap;
  final Set<String> dimmedShapeIds;
  final bool interactive;
  final String fullscreenTitle;
  final bool allowFullscreen;
  final bool showZoomControls;

  @override
  State<ShapeCanvas> createState() => _ShapeCanvasState();
}

class _ShapeCanvasState extends State<ShapeCanvas> {
  static const _minScale = 0.1;
  static const _maxScale = 8.0;
  static const _fitPadding = AppSpacing.lg;

  final TransformationController _controller = TransformationController();
  Size? _fittedViewport;
  Size _viewportSize = Size.zero;
  ui.Image? _background;

  @override
  void initState() {
    super.initState();
    _loadBackground(widget.canvasSize.backgroundImagePath);
  }

  @override
  void didUpdateWidget(covariant ShapeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasSize != widget.canvasSize) {
      _fittedViewport = null;
    }
    if (oldWidget.canvasSize.backgroundImagePath !=
        widget.canvasSize.backgroundImagePath) {
      _loadBackground(widget.canvasSize.backgroundImagePath);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _background?.dispose();
    super.dispose();
  }

  /// Background decode is async — the loaded [ui.Image] is only ever applied
  /// via [setState], so the painter is guaranteed a repaint once it resolves
  /// rather than silently never showing the image. A missing or undecodable
  /// file is caught and simply skipped; the map still renders without it.
  Future<void> _loadBackground(String? path) async {
    if (path == null) {
      final previous = _background;
      if (previous == null) return;
      setState(() => _background = null);
      previous.dispose();
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (!mounted || widget.canvasSize.backgroundImagePath != path) {
        image.dispose();
        return;
      }
      final previous = _background;
      setState(() => _background = image);
      previous?.dispose();
    } catch (_) {
      // Missing/undecodable background file — render without it.
    }
  }

  void _fitToViewport(BoxConstraints constraints) {
    if (widget.canvasSize.width == 0 || widget.canvasSize.height == 0) {
      return;
    }

    final viewport = Size(constraints.maxWidth, constraints.maxHeight);
    if (!viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.isEmpty) {
      return;
    }

    final availableWidth = math.max(0.0, viewport.width - (_fitPadding * 2));
    final availableHeight = math.max(0.0, viewport.height - (_fitPadding * 2));
    final scale = math
        .min(
          availableWidth / widget.canvasSize.width,
          availableHeight / widget.canvasSize.height,
        )
        .clamp(_minScale, 1.0);
    final left = (viewport.width - (widget.canvasSize.width * scale)) / 2;
    final top = (viewport.height - (widget.canvasSize.height * scale)) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(left, top, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    _fittedViewport = viewport;
  }

  void _zoomBy(double factor) {
    if (_viewportSize.isEmpty) return;

    final currentScale = _controller.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    if ((targetScale - currentScale).abs() < 0.001) return;

    final viewportCenter = Offset(
      _viewportSize.width / 2,
      _viewportSize.height / 2,
    );
    final sceneCenter = _controller.toScene(viewportCenter);
    _controller.value = Matrix4.identity()
      ..translateByDouble(viewportCenter.dx, viewportCenter.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, targetScale, 1)
      ..translateByDouble(-sceneCenter.dx, -sceneCenter.dy, 0, 1);
  }

  Future<void> _openFullscreen() async {
    final selectedShapeId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenShapeCanvasPage(
          title: widget.fullscreenTitle,
          canvasSize: widget.canvasSize,
          shapes: widget.shapes,
          dimmedShapeIds: widget.dimmedShapeIds,
        ),
      ),
    );
    if (!mounted || selectedShapeId == null) return;
    widget.onShapeTap(selectedShapeId);
  }

  void _handleTap(Offset localPosition) {
    final hit = _hitTestShapes(widget.shapes, localPosition);
    if (hit != null) widget.onShapeTap(hit);
  }

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      key: const ValueKey('shape-map-content'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition),
      child: SizedBox(
        width: widget.canvasSize.width,
        height: widget.canvasSize.height,
        child: CustomPaint(
          painter: _ShapePainter(
            shapes: widget.shapes,
            dimmedShapeIds: widget.dimmedShapeIds,
            background: _background,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _viewportSize = viewport;

        if (widget.interactive && _fittedViewport != viewport) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _viewportSize == viewport) {
              _fitToViewport(constraints);
            }
          });
        }

        final map = widget.interactive
            ? InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                alignment: Alignment.topLeft,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(160),
                child: content,
              )
            : FittedBox(fit: BoxFit.contain, child: content);

        return Stack(
          fit: StackFit.expand,
          children: [
            map,
            if (widget.allowFullscreen)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _MapControlButton(
                  key: const ValueKey('shape-map-expand-button'),
                  icon: Icons.fullscreen,
                  tooltip: 'Open full screen map',
                  onPressed: _openFullscreen,
                ),
              ),
            if (widget.showZoomControls && widget.interactive)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Row(
                  children: [
                    _MapControlButton(
                      key: const ValueKey('shape-map-zoom-out-button'),
                      icon: Icons.remove,
                      tooltip: 'Zoom out',
                      onPressed: () => _zoomBy(0.75),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _MapControlButton(
                      key: const ValueKey('shape-map-fit-button'),
                      icon: Icons.fit_screen,
                      tooltip: 'Fit map to screen',
                      onPressed: () => _fitToViewport(constraints),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _MapControlButton(
                      key: const ValueKey('shape-map-zoom-in-button'),
                      icon: Icons.add,
                      tooltip: 'Zoom in',
                      onPressed: () => _zoomBy(1.35),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FullscreenShapeCanvasPage extends StatelessWidget {
  const _FullscreenShapeCanvasPage({
    required this.title,
    required this.canvasSize,
    required this.shapes,
    required this.dimmedShapeIds,
  });

  final String title;
  final CanvasSize canvasSize;
  final List<CanvasShape> shapes;
  final Set<String> dimmedShapeIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: AppColors.surfaceNeutral,
                child: ShapeCanvas(
                  canvasSize: canvasSize,
                  shapes: shapes,
                  dimmedShapeIds: dimmedShapeIds,
                  fullscreenTitle: title,
                  allowFullscreen: false,
                  showZoomControls: true,
                  onShapeTap: (id) => Navigator.of(context).pop(id),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(
                'Pinch or use the zoom controls, then tap an item to select it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.textSecondaryIcon,
      ),
    );
  }
}

/// Lines take priority over rects at the same point (walls sit visually on
/// top of a room's fill), then rects, in reverse paint order (topmost drawn
/// shape wins).
String? _hitTestShapes(List<CanvasShape> shapes, Offset point) {
  for (final shape in shapes.reversed) {
    if (!shape.selectable) continue;
    if (shape is CanvasLine && shape.line.isNear(point)) return shape.id;
  }
  for (final shape in shapes.reversed) {
    if (!shape.selectable) continue;
    if (shape is CanvasRect && shape.rect.contains(point)) return shape.id;
  }
  return null;
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({
    required this.shapes,
    required this.dimmedShapeIds,
    this.background,
  });

  final List<CanvasShape> shapes;
  final Set<String> dimmedShapeIds;
  final ui.Image? background;

  @override
  void paint(Canvas canvas, Size size) {
    final background = this.background;
    if (background != null) {
      canvas.drawImageRect(
        background,
        Rect.fromLTWH(
          0,
          0,
          background.width.toDouble(),
          background.height.toDouble(),
        ),
        Offset.zero & size,
        Paint(),
      );
    }
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
