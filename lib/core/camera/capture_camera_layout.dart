import 'dart:async';

import 'package:flutter/material.dart';

import '../hardware/screen_orientation_channel.dart';
import '../theme/app_spacing.dart';
import '../theme/camera_metrics.dart';

/// Where a capture screen's pieces go, held upright or sideways. A page says
/// what it shows; this decides where:
///
/// - upright: the viewfinder, then [gridMap], then a row of [shots] | [shutter] | [finish];
/// - sideways: the viewfinder on the left, and a rail on the right holding
///   [gridMap], [shots], [shutter] and [finish] from top to bottom.
///
/// While it is on screen the phone's sensor turns the screen even with
/// auto-rotate off, so turning the phone for a wide wall always gets this
/// sideways layout. The photograph needs nothing extra for it: the camera
/// tags each shot with the way the phone was held.
class CaptureCameraLayout extends StatefulWidget {
  const CaptureCameraLayout({
    super.key,
    required this.viewfinder,
    required this.shutter,
    this.topStart,
    this.topCenter,
    this.topEnd,
    this.zoom,
    this.gridMap,
    this.shots,
    this.finish,
  });

  final Widget viewfinder;
  final Widget shutter;

  /// Laid over the top of the viewfinder.
  final Widget? topStart;
  final Widget? topCenter;
  final Widget? topEnd;

  /// Laid over the bottom of the viewfinder.
  final Widget? zoom;

  final Widget? gridMap;

  /// The shots taken so far, built for the direction they have room to run in:
  /// across under the viewfinder, or down the rail beside it.
  final Widget Function(Axis axis)? shots;

  /// Done, Review or the like: what closes the camera with the shots.
  final Widget? finish;

  @override
  State<CaptureCameraLayout> createState() => _CaptureCameraLayoutState();
}

class _CaptureCameraLayoutState extends State<CaptureCameraLayout> {
  @override
  void initState() {
    super.initState();
    unawaited(ScreenOrientationChannel.followSensor());
  }

  @override
  void dispose() {
    unawaited(ScreenOrientationChannel.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideways = constraints.maxWidth > constraints.maxHeight;
        final viewfinder = _ViewfinderWithOverlays(
          viewfinder: widget.viewfinder,
          topStart: widget.topStart,
          topCenter: widget.topCenter,
          topEnd: widget.topEnd,
          zoom: widget.zoom,
        );
        if (!sideways) {
          return Column(
            children: [
              Expanded(child: viewfinder),
              widget.gridMap ?? const SizedBox.shrink(),
              _UprightFooter(
                shots: widget.shots,
                shutter: widget.shutter,
                finish: widget.finish,
              ),
            ],
          );
        }
        final railWidth =
            (constraints.maxWidth * CameraMetrics.railWidthFraction)
                .clamp(CameraMetrics.railMinWidth, CameraMetrics.railMaxWidth)
                .toDouble();
        return Row(
          children: [
            Expanded(child: viewfinder),
            SizedBox(
              width: railWidth,
              child: _SidewaysRail(
                gridMap: widget.gridMap,
                shots: widget.shots,
                shutter: widget.shutter,
                finish: widget.finish,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewfinderWithOverlays extends StatelessWidget {
  const _ViewfinderWithOverlays({
    required this.viewfinder,
    required this.topStart,
    required this.topCenter,
    required this.topEnd,
    required this.zoom,
  });

  final Widget viewfinder;
  final Widget? topStart;
  final Widget? topCenter;
  final Widget? topEnd;
  final Widget? zoom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        viewfinder,
        if (topStart != null)
          PositionedDirectional(
            top: AppSpacing.lg,
            start: AppSpacing.lg,
            child: topStart!,
          ),
        if (topCenter != null)
          Positioned(top: AppSpacing.lg, child: topCenter!),
        if (topEnd != null)
          PositionedDirectional(
            top: AppSpacing.lg,
            end: AppSpacing.lg,
            child: topEnd!,
          ),
        // Given the viewfinder's width to stay inside: an overlay with words in it
        // (the scan's guidance) wraps instead of running off both edges.
        if (zoom != null)
          Positioned(
            bottom: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Center(child: zoom!),
          ),
      ],
    );
  }
}

class _UprightFooter extends StatelessWidget {
  const _UprightFooter({
    required this.shots,
    required this.shutter,
    required this.finish,
  });

  final Widget Function(Axis axis)? shots;
  final Widget shutter;
  final Widget? finish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: shots?.call(Axis.horizontal),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          shutter,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidewaysRail extends StatelessWidget {
  const _SidewaysRail({
    required this.gridMap,
    required this.shots,
    required this.shutter,
    required this.finish,
  });

  final Widget? gridMap;
  final Widget Function(Axis axis)? shots;
  final Widget shutter;
  final Widget? finish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          gridMap ?? const SizedBox.shrink(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(child: shots?.call(Axis.vertical)),
            ),
          ),
          shutter,
          if (finish != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: finish,
            ),
          ],
        ],
      ),
    );
  }
}
