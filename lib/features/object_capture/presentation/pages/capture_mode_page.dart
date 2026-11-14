import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/domain/entities/object_type.dart';
import '../../domain/entities/object_scan.dart';
import '../cubit/object_capture_state.dart';
import '../object_capture_routes.dart';
import '../widgets/capture_mode_card.dart';
import '../widgets/object_capture_scaffold.dart';

/// Where photographing an object starts: the operator picks how. The ways
/// can be mixed on one object, so each card shows what it already holds.
class CaptureModePage extends StatelessWidget {
  const CaptureModePage({super.key, required this.routes});

  final ObjectCaptureRoutes routes;

  @override
  Widget build(BuildContext context) {
    return ObjectCaptureScaffold(
      floorId: routes.floorId,
      wallId: routes.wallId,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: state.wall.name,
            subtitle: 'Choose how to photograph it.',
            onBack: () => context.safePop(),
          ),
          Expanded(
            child: _ModeCards(routes: routes, state: state),
          ),
        ],
      ),
    );
  }
}

String _scanProgress(ObjectScan? scan) {
  if (scan == null) return 'Not started';
  return switch (scan.stage) {
    ScanStage.capturing => '${scan.shots.length} photographs taken',
    ScanStage.uploading => 'Sending the photographs',
    ScanStage.checking => 'Being checked',
    ScanStage.needsMorePhotos => 'More photographs needed',
    ScanStage.buildingModel => 'Model being built',
    ScanStage.modelReady => 'Model ready',
    ScanStage.failed => 'Could not be processed',
    ScanStage.cancelled => 'Cancelled',
  };
}

class _ModeCards extends StatelessWidget {
  const _ModeCards({required this.routes, required this.state});

  /// Past this width there is room for the cards side by side — a phone held
  /// sideways, or a tablet.
  static const double _twoColumnBreakpoint = 600;

  final ObjectCaptureRoutes routes;
  final ObjectCaptureLoaded state;

  @override
  Widget build(BuildContext context) {
    final capture = state.capture;
    final sideCount = ObjectSide.values.length;
    final freeCount = capture.freePhotos.length;

    final cards = [
      // A wall kept as loose photographs has no six sides to walk round.
      if (!state.wall.objectType.isFlat)
        CaptureModeCard(
          icon: Icons.view_in_ar_outlined,
          title: 'Organised',
          description:
              'One photograph of each side: front, back, left, right, top '
              'and bottom.',
          progress: '${capture.sidesCaptured} of $sideCount sides',
          onTap: () => context.push(routes.organised),
        ),
      CaptureModeCard(
        icon: Icons.photo_library_outlined,
        title: 'Free capture',
        description:
            'Any number of photographs, each with a short description of '
            'what it shows.',
        progress: freeCount == 1 ? '1 photograph' : '$freeCount photographs',
        onTap: () => context.push(routes.free),
      ),
      if (!state.wall.objectType.isFlat)
        CaptureModeCard(
          icon: Icons.threed_rotation,
          title: '3D scan',
          description:
              'Walk slowly round the object. The app takes the photographs '
              'and shows which sides are still missing.',
          progress: _scanProgress(state.scan),
          // A scan handed over is followed on its own screen; one still
          // being shot goes back to the camera.
          onTap: () => context.push(
            state.scan?.isFinished ?? false ? routes.scanStatus : routes.scan,
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _twoColumnBreakpoint ? 2 : 1;
        const gap = AppSpacing.md;
        const edge = AppSpacing.lg;
        final cardWidth =
            (constraints.maxWidth - edge * 2 - gap * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(edge, 0, edge, AppSpacing.xl),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: cardWidth, child: card),
            ],
          ),
        );
      },
    );
  }
}
