import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../cubit/capture_session_cubit.dart';
import '../cubit/capture_session_state.dart';
import '../widgets/capture_screen_header.dart';
import '../widgets/grid_capture_metrics.dart';
import '../widgets/grid_preset_row.dart';
import '../widgets/grid_stepper_row.dart';

class GridInitPage extends StatelessWidget {
  const GridInitPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
    required this.wallName,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;
  final String wallName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CaptureSessionCubit(
        GetIt.instance<GridCaptureRepository>(),
        GetIt.instance<GridCaptureLocalDataSource>(),
      )..init(floorId, wallId),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              CaptureScreenHeader(
                title: 'Set up grid',
                subtitle: '$wallName · choose a coverage grid',
                onBack: () => context.safePop(),
                subtitleBottomPadding: GridCaptureMetrics.horizontalPadding,
              ),
              Expanded(
                child: BlocBuilder<CaptureSessionCubit, CaptureSessionState>(
                  builder: (context, state) => switch (state) {
                    CaptureSessionLoading() => const LoadingIndicator(),
                    CaptureSessionError(:final message) => ErrorRetryView(
                      message: message,
                      onRetry: () => context.read<CaptureSessionCubit>().init(
                        floorId,
                        wallId,
                      ),
                    ),
                    CaptureSessionNotFound() => EmptyState(
                      icon: Icons.search_off,
                      message: 'This wall could not be found.',
                      actionLabel: 'Back to site',
                      onAction: () => context.go(
                        '/sites/$siteId/buildings/$buildingId/floors/$floorId',
                      ),
                    ),
                    CaptureSessionLoaded() => _GridInitForm(
                      siteId: siteId,
                      buildingId: buildingId,
                      floorId: floorId,
                      wallId: wallId,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridInitForm extends StatelessWidget {
  const _GridInitForm({
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  /// Storage watchdog (FLUTTER_MOBILE_PLAN.md Phase 7): warns but proceeds
  /// on [StorageCheckResult.low], blocks entirely on
  /// [StorageCheckResult.critical] rather than letting a session start that
  /// can't hold its own photos.
  Future<void> _startGrid(
    BuildContext context,
    CaptureSessionCubit cubit,
    int cellCount,
    VoidCallback createGrid,
  ) async {
    final result = await cubit.checkStorageForNewSession(cellCount);
    if (!context.mounted) return;

    if (result == StorageCheckResult.critical) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not enough free storage to start this capture. Free up space and try again.',
          ),
        ),
      );
      return;
    }
    if (result == StorageCheckResult.low) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Storage is running low — consider freeing up space soon.',
          ),
        ),
      );
    }

    createGrid();
    context.push(
      '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/$wallId/grid-capture',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptureSessionCubit>();
    final state =
        context.watch<CaptureSessionCubit>().state as CaptureSessionLoaded;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        GridCaptureMetrics.horizontalPadding,
        0,
        GridCaptureMetrics.horizontalPadding,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('PRESETS'),
          const SizedBox(height: AppSpacing.sm + 2),
          for (final preset in kGridPresets) ...[
            GridPresetRow(
              label: preset.label,
              cellCount: preset.rows * preset.cols,
              onTap: () => _startGrid(
                context,
                cubit,
                preset.rows * preset.cols,
                () => cubit.pickPreset(preset.rows, preset.cols),
              ),
            ),
            const SizedBox(height: GridCaptureMetrics.gap),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('CUSTOM'),
          const SizedBox(height: AppSpacing.sm + 2),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineSubtle, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                GridStepperRow(
                  label: 'Rows',
                  value: state.customRows,
                  onIncrement: cubit.incRows,
                  onDecrement: cubit.decRows,
                ),
                const SizedBox(height: AppSpacing.lg),
                GridStepperRow(
                  label: 'Columns',
                  value: state.customCols,
                  onIncrement: cubit.incCols,
                  onDecrement: cubit.decCols,
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.customCellCount} cells total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryActionButton(
                  label: 'Use custom grid',
                  onTap: () => _startGrid(
                    context,
                    cubit,
                    state.customCellCount,
                    cubit.useCustomGrid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onSurfaceMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
