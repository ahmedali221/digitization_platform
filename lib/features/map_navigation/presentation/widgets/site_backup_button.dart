import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../site_backup/domain/services/site_backup_service.dart';
import '../../../site_backup/presentation/cubit/site_backup_cubit.dart';
import '../../../site_backup/presentation/cubit/site_backup_state.dart';

/// Header action on [BuildingsListPage]: zips every captured photo for the
/// site into one file mirroring its building/floor/wall structure, then
/// hands it to the OS share sheet so the operator can save or send it
/// off-device.
class SiteBackupButton extends StatelessWidget {
  const SiteBackupButton({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  final String siteId;
  final String siteName;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.folder_zip_outlined,
      onTap: () => _startBackup(context),
      visualDiameter: 40,
      iconSize: 22,
      color: AppColors.textPrimary,
    );
  }

  Future<void> _startBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Back up images?'),
        content: Text(
          'Creates a zip of every captured photo for $siteName, organized '
          'by building, floor, and wall, ready to share or save.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 140,
            child: PrimaryActionButton(
              label: 'Back up',
              onTap: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final cubit = SiteBackupCubit(GetIt.instance<SiteBackupService>());
    cubit.backup(siteId);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocConsumer<SiteBackupCubit, SiteBackupState>(
          listener: (dialogContext, state) {
            if (state is SiteBackupReady || state is SiteBackupFailed) {
              Navigator.of(dialogContext).pop();
            }
          },
          builder: (_, state) => AlertDialog(
            title: const Text('Backing up images…'),
            content: _BackupProgress(state: state),
          ),
        ),
      ),
    );

    final finalState = cubit.state;
    await cubit.close();

    if (finalState is SiteBackupReady) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(finalState.zipPath)],
          subject: '$siteName — image backup',
        ),
      );
    } else if (finalState is SiteBackupFailed && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Backup failed: ${finalState.message}')),
      );
    }
  }
}

class _BackupProgress extends StatelessWidget {
  const _BackupProgress({required this.state});

  final SiteBackupState state;

  @override
  Widget build(BuildContext context) {
    final inProgress = state is SiteBackupInProgress
        ? state as SiteBackupInProgress
        : null;
    final total = inProgress?.total ?? 0;
    final done = inProgress?.done ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: total > 0 ? done / total : null),
        const SizedBox(height: AppSpacing.sm),
        Text(total > 0 ? '$done / $total photos' : 'Preparing…'),
      ],
    );
  }
}
