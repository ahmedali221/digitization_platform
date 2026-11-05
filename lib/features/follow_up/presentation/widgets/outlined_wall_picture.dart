import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/follow_up_package.dart';

/// A wall picture with the annotation outlined on it, to find the spot at the
/// site. Pinch to zoom: on a long wall the whole picture is small. The outline
/// is drawn over the image rather than into it, so it stays sharp when zoomed.
class OutlinedWallPicture extends StatelessWidget {
  const OutlinedWallPicture({
    super.key,
    required this.path,
    required this.picture,
    required this.polygon,
  });

  static const double _maxZoom = 8;

  final String path;
  final WallPicture picture;
  final List<NormalizedPoint> polygon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InteractiveViewer(
        maxScale: _maxZoom,
        child: AspectRatio(
          aspectRatio: picture.width / picture.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, color: AppColors.iconMuted),
              ),
              CustomPaint(painter: _OutlinePainter(polygon)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.polygon);

  final List<NormalizedPoint> polygon;

  static const Color _outline = Color(0xFFFF3B30);
  static const double _strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.isEmpty) return;
    final path = Path()
      ..addPolygon(
        [for (final point in polygon) Offset(point.x * size.width, point.y * size.height)],
        true,
      );
    canvas
      ..drawPath(path, Paint()..color = _outline.withValues(alpha: 0.18))
      ..drawPath(
        path,
        Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) => oldDelegate.polygon != polygon;
}
