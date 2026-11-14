import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/multi_shot_camera_page.dart';
import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/captured_photo_review.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/widgets/thin_progress_bar.dart';
import '../../domain/entities/object_capture.dart';
import '../cubit/object_capture_cubit.dart';
import '../cubit/object_capture_state.dart';
import '../object_capture_routes.dart';
import '../widgets/object_capture_scaffold.dart';
import '../widgets/side_tile.dart';

/// Organised capture: one photograph for each of the object's six sides.
/// A tile with no photograph opens the camera; one with a photograph opens
/// it, to be kept, retaken or deleted.
class OrganisedCapturePage extends StatelessWidget {
  const OrganisedCapturePage({super.key, required this.routes});

  final ObjectCaptureRoutes routes;

  @override
  Widget build(BuildContext context) {
    return ObjectCaptureScaffold(
      floorId: routes.floorId,
      wallId: routes.wallId,
      builder: (context, state) =>
          _OrganisedContent(routes: routes, state: state),
    );
  }
}

class _OrganisedContent extends StatelessWidget {
  const _OrganisedContent({required this.routes, required this.state});

  /// The widest a side tile grows before another column is added.
  static const double _maxTileExtent = 220;

  final ObjectCaptureRoutes routes;
  final ObjectCaptureLoaded state;

  void _onSideTapped(
    BuildContext context,
    ObjectSide side,
    ObjectPhoto? photo,
  ) {
    if (photo == null) {
      _shoot(context, side);
    } else {
      _open(context, side, photo.path);
    }
  }

  Future<void> _shoot(BuildContext context, ObjectSide side) async {
    final cubit = context.read<ObjectCaptureCubit>();
    final navigator = Navigator.of(context);
    final folder = await cubit.incomingFolder();

    final shots = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (_) => MultiShotCameraPage(
          title: '${state.wall.name} · ${side.label}',
          folder: folder,
          singleShot: true,
        ),
      ),
    );
    if (shots == null || shots.isEmpty) return;
    await cubit.keepSidePhoto(side, shots.last);
  }

  Future<void> _open(BuildContext context, ObjectSide side, String path) async {
    final cubit = context.read<ObjectCaptureCubit>();
    final decision = await reviewCapturedPhoto(
      context,
      path,
      label: side.label,
      canRetake: true,
    );
    if (!context.mounted) return;

    switch (decision) {
      case CapturedPhotoDecision.delete:
        await cubit.deletePhoto(path);
      case CapturedPhotoDecision.retake:
        await _shoot(context, side);
      case null:
        break;
    }
  }

  Future<void> _save(BuildContext context) async {
    await context.read<ObjectCaptureCubit>().save();
    if (context.mounted) context.popToPath(routes.wall);
  }

  @override
  Widget build(BuildContext context) {
    final capture = state.capture;
    final sidePhotos = capture.sidePhotos;
    final sideCount = ObjectSide.values.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Six sides',
          subtitle: '${capture.sidesCaptured} of $sideCount photographed',
          onBack: () => context.safePop(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ThinProgressBar(progress: capture.sidesCaptured / sideCount),
        ),
        Expanded(
          child: GridView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxTileExtent,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
            ),
            children: [
              for (final side in ObjectSide.values)
                SideTile(
                  side: side,
                  photoPath: sidePhotos[side]?.path,
                  onTap: () => _onSideTapped(context, side, sidePhotos[side]),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: PrimaryActionButton(
            label: capture.hasEverySide ? 'Save' : 'Save partial',
            enabled: sidePhotos.isNotEmpty,
            onTap: () => _save(context),
          ),
        ),
      ],
    );
  }
}
