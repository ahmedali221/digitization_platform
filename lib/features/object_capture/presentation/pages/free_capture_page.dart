import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/multi_shot_camera_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/captured_photo_review.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/screen_header.dart';
import '../cubit/object_capture_cubit.dart';
import '../cubit/object_capture_state.dart';
import '../object_capture_routes.dart';
import '../widgets/commented_photo_card.dart';
import '../widgets/object_capture_scaffold.dart';

/// Free capture: any photographs of the object, each described by the
/// operator. Saving waits for every description, because an unlabelled
/// photograph of an unknown side is of little use on the dashboard.
class FreeCapturePage extends StatelessWidget {
  const FreeCapturePage({super.key, required this.routes});

  final ObjectCaptureRoutes routes;

  @override
  Widget build(BuildContext context) {
    return ObjectCaptureScaffold(
      floorId: routes.floorId,
      wallId: routes.wallId,
      onOpened: (cubit) => cubit.adoptStrayShots(),
      builder: (context, state) => _FreeContent(routes: routes, state: state),
    );
  }
}

class _FreeContent extends StatelessWidget {
  const _FreeContent({required this.routes, required this.state});

  final ObjectCaptureRoutes routes;
  final ObjectCaptureLoaded state;

  Future<void> _shoot(BuildContext context) async {
    final cubit = context.read<ObjectCaptureCubit>();
    final navigator = Navigator.of(context);
    final folder = await cubit.incomingFolder();

    final shots = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (_) =>
            MultiShotCameraPage(title: state.wall.name, folder: folder),
      ),
    );
    if (shots == null) return;
    await cubit.keepFreePhotos(shots);
  }

  Future<void> _open(BuildContext context, String path) async {
    final cubit = context.read<ObjectCaptureCubit>();
    final decision = await reviewCapturedPhoto(context, path);
    if (decision == CapturedPhotoDecision.delete) await cubit.deletePhoto(path);
  }

  Future<void> _save(BuildContext context) async {
    await context.read<ObjectCaptureCubit>().save();
    if (context.mounted) context.popToPath(routes.wall);
  }

  @override
  Widget build(BuildContext context) {
    final capture = state.capture;
    final photos = capture.freePhotos;
    final cubit = context.read<ObjectCaptureCubit>();
    final canSave = photos.isNotEmpty && !capture.hasUncommentedFreePhoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Free capture',
          subtitle: photos.length == 1
              ? '1 photograph'
              : '${photos.length} photographs',
          onBack: () => context.safePop(),
        ),
        Expanded(
          child: photos.isEmpty
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  message:
                      'Photograph the object from wherever its inscriptions '
                      'are, then say what each picture shows.',
                  actionLabel: 'Take photographs',
                  onAction: () => _shoot(context),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: photos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return CommentedPhotoCard(
                      key: ValueKey(photo.path),
                      photo: photo,
                      onOpen: () => _open(context, photo.path),
                      onCommentChanged: (comment) =>
                          cubit.setComment(photo.path, comment),
                    );
                  },
                ),
        ),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (capture.hasUncommentedFreePhoto) ...[
                  Text(
                    'Describe every photograph to save.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onWarningContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SecondaryActionButton(
                  icon: Icons.add_a_photo_outlined,
                  label: 'Add photographs',
                  onTap: () => _shoot(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryActionButton(
                  label: 'Save',
                  enabled: canSave,
                  onTap: () => _save(context),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
