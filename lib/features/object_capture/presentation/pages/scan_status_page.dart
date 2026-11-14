import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../domain/entities/object_scan.dart';
import '../../domain/repositories/object_scan_repository.dart';
import '../cubit/scan_status_cubit.dart';
import '../object_capture_routes.dart';
import '../widgets/scan_preview_panel.dart';
import '../widgets/scan_stage_panel.dart';

/// What became of a 3D scan once the operator finished shooting: its upload,
/// the server's check of its coverage, the rough model built from it, and
/// the way back to the camera for whatever either of them shows missing.
class ScanStatusPage extends StatelessWidget {
  const ScanStatusPage({super.key, required this.routes});

  final ObjectCaptureRoutes routes;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanStatusCubit(
        GetIt.instance<ObjectScanRepository>(),
        GetIt.instance<SiteRepository>(),
        floorId: routes.floorId,
        wallId: routes.wallId,
      ),
      child: Scaffold(
        body: SafeArea(
          child: BlocConsumer<ScanStatusCubit, ScanStatusState>(
            listenWhen: (previous, current) =>
                current.isReopened && !previous.isReopened,
            listener: (context, state) => context.pushReplacement(routes.scan),
            builder: (context, state) {
              final scan = state.scan;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: state.objectName,
                    subtitle: '3D scan',
                    onBack: () => context.safePop(),
                  ),
                  Expanded(
                    child: scan == null
                        ? const EmptyState(
                            icon: Icons.threed_rotation,
                            message: 'This object has not been scanned yet.',
                          )
                        : _ScanStatusBody(scan: scan),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScanStatusBody extends StatelessWidget {
  const _ScanStatusBody({required this.scan});

  final ObjectScan scan;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanStatusCubit>();
    final preview = scan.server?.preview;
    // A failed scan is shot again like one that needs more: its photographs
    // are still on the server, and new ones are added to them.
    final wasAskedForMore =
        scan.stage == ScanStage.needsMorePhotos ||
        scan.stage == ScanStage.failed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScanStagePanel(scan: scan),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.xl),
            ScanPreviewPanel(preview: preview),
          ],
          // A scan the server found complete can still show a hole in its
          // rough model, and is gone back to in the same way.
          if (wasAskedForMore || scan.missingParts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryActionButton(
              label: 'Photograph the missing parts',
              icon: Icons.photo_camera,
              onTap: cubit.captureMore,
            ),
          ],
          if (wasAskedForMore) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryActionButton(
              label: 'Scan again from the start',
              icon: Icons.restart_alt,
              onTap: () => cubit.captureMore(fromTheStart: true),
            ),
          ],
        ],
      ),
    );
  }
}
