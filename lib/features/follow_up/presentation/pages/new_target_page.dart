import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/target_width.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/repositories/new_target_repository.dart';
import '../cubit/new_target_cubit.dart';
import '../cubit/new_target_state.dart';
import '../widgets/new_target_details_form.dart';
import '../widgets/new_target_photo_section.dart';
import '../../../../core/camera/multi_shot_camera_page.dart';
import 'shot_review_page.dart';
import 'target_width_page.dart';

/// Adds a target the site had no profile for. It's saved on this phone and sent
/// when there's a signal; the dashboard reviews it, and the studio then makes it
/// a profile, which the next package lists like any other target.
class NewTargetPage extends StatelessWidget {
  const NewTargetPage({super.key, required this.package});

  final FollowUpPackage package;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewTargetCubit(
        newTargets: GetIt.instance<NewTargetRepository>(),
        followUp: GetIt.instance<FollowUpRepository>(),
        package: package,
      ),
      child: const _NewTargetView(),
    );
  }
}

class _NewTargetView extends StatelessWidget {
  const _NewTargetView();

  static const String _title = 'New target';

  Future<void> _photograph(BuildContext context) async {
    final cubit = context.read<NewTargetCubit>();
    final navigator = Navigator.of(context);
    final folder = await cubit.shotsFolder();

    final shots = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (_) => MultiShotCameraPage(title: _title, folder: folder),
      ),
    );
    if (shots == null || shots.isEmpty) return;

    final chosen = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => ShotReviewPage(shots: shots)),
    );
    if (chosen != null) cubit.setPhoto(chosen);
  }

  /// Last, so a retake never costs a measurement. The width page saves the
  /// target, and stays open to try again if saving fails.
  Future<void> _measureAndSave(
    BuildContext context,
    NewTargetState state,
  ) async {
    final cubit = context.read<NewTargetCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final saved = await navigator.push<TargetWidth>(
      MaterialPageRoute(
        builder: (_) => TargetWidthPage(
          title: state.details.trimmedCode,
          imagePath: state.photoPath!,
          onSave: cubit.save,
        ),
      ),
    );
    if (saved == null) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Saved. It will be reviewed on the dashboard, then created in the studio.',
        ),
      ),
    );
    navigator.pop(true);
  }

  Future<bool> _confirmLeaving(BuildContext context) => ConfirmDialog.show(
    context,
    title: 'Leave this new target?',
    message: 'Its photograph and details have not been saved.',
    confirmLabel: 'Leave',
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewTargetCubit, NewTargetState>(
      builder: (context, state) {
        final cubit = context.read<NewTargetCubit>();
        return PopScope(
          canPop: state.photoPath == null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmLeaving(context)) navigator.pop();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text(_title)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'For a target this site has no profile for yet. Once it is approved on the dashboard, '
                    'the studio makes it a profile, with no video yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NewTargetPhotoSection(
                    photoPath: state.photoPath,
                    onTake: () => _photograph(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NewTargetDetailsForm(
                    details: state.details,
                    conflict: state.conflict,
                    onCodeChanged: cubit.setCode,
                    onDescriptionChanged: cubit.setDescription,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryActionButton(
                    icon: Icons.straighten,
                    label: 'Measure its width and save',
                    enabled: state.readyToMeasure,
                    onTap: () => _measureAndSave(context, state),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
