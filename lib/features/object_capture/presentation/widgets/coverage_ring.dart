import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scan_coverage.dart';
import '../../domain/entities/scan_plan.dart';

/// The ring being shot, seen from above: the object is the middle, each
/// slice a photograph, filled once it is taken. The scan began at the
/// bottom, and the marker is where the operator stands now, so a gap to the
/// right of the marker is a step to the right.
class CoverageRing extends StatelessWidget {
  const CoverageRing({
    super.key,
    required this.coverage,
    required this.ring,
    required this.azimuth,
  });

  static const double _maxDiameter = 132;

  final ScanCoverage coverage;
  final int ring;

  /// Degrees round the object from where the scan began.
  final int azimuth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sectors = ScanPlan.rings[ring].sectors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(
          _maxDiameter,
          constraints.biggest.shortestSide,
        );
        return SizedBox.square(
          dimension: diameter,
          child: CustomPaint(
            painter: _RingPainter(
              coverage: coverage,
              ring: ring,
              azimuth: azimuth,
            ),
            child: Center(
              child: FittedBox(
                child: Text(
                  '${coverage.capturedIn(ring)}/$sectors',
                  style: textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.coverage,
    required this.ring,
    required this.azimuth,
  });

  static const double _thicknessFraction = 0.12;
  static const double _gapDegrees = 2;
  static const double _markerRadiusFraction = 0.07;
  static const Color _pending = Color(0x59FFFFFF);
  static const Color _taken = Colors.white;

  final ScanCoverage coverage;
  final int ring;
  final int azimuth;

  @override
  void paint(Canvas canvas, Size size) {
    final thickness = size.shortestSide * _thicknessFraction;
    final bounds = (Offset.zero & size).deflate(thickness / 2);
    final slice = ScanPlan.rings[ring].sectorDegrees;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    for (var sector = 0; sector < ScanPlan.rings[ring].sectors; sector++) {
      stroke.color = coverage.isCaptured(ScanCell(ring, sector))
          ? _taken
          : _pending;
      canvas.drawArc(
        bounds,
        _canvasAngle(sector * slice + _gapDegrees / 2),
        -_radians(slice - _gapDegrees),
        false,
        stroke,
      );
    }

    final markerAngle = _canvasAngle(azimuth.toDouble());
    final markerCentre =
        bounds.center +
        Offset(math.cos(markerAngle), math.sin(markerAngle)) *
            (bounds.width / 2);
    canvas.drawCircle(
      markerCentre,
      size.shortestSide * _markerRadiusFraction,
      Paint()..color = AppColors.seed,
    );
  }

  /// Where [azimuth] degrees round the object falls on the canvas: the scan
  /// began at the bottom, and going right round the object is anticlockwise
  /// seen from above, which a canvas measures as a negative angle.
  double _canvasAngle(double azimuth) => _radians(90 - azimuth);

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.coverage != coverage || old.ring != ring || old.azimuth != azimuth;
}
