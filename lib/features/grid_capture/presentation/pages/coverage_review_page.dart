import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../../core/utils/navigation_extensions.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../data/datasources/grid_capture_local_data_source.dart';
import '../../domain/repositories/grid_capture_repository.dart';
import '../../domain/services/grid_preview_composer.dart';
import '../cubit/capture_session_cubit.dart';
import '../cubit/capture_session_state.dart';
import '../widgets/capture_screen_header.dart';
import '../widgets/grid_capture_metrics.dart';
import '../widgets/grid_cell_tile.dart';
import 'grid_preview_screen.dart';

class CoverageReviewPage extends StatelessWidget {
  const CoverageReviewPage({
    super.key,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CaptureSessionCubit(
        GetIt.instance<GridCaptureRepository>(),
        GetIt.instance<GridCaptureLocalDataSource>(),
      )..init(floorId, wallId),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<CaptureSessionCubit, CaptureSessionState>(
            builder: (context, state) => switch (state) {
              CaptureSessionLoading() => const LoadingIndicator(),
              CaptureSessionError(:final message) => ErrorRetryView(
                message: message,
                onRetry: () =>
                    context.read<CaptureSessionCubit>().init(floorId, wallId),
              ),
              CaptureSessionNotFound() => EmptyState(
                icon: Icons.search_off,
                message: 'This wall could not be found.',
                actionLabel: 'Back to site',
                onAction: () => context.go(
                  '/sites/$siteId/buildings/$buildingId/floors/$floorId',
                ),
              ),
              CaptureSessionLoaded(grid: null) => const EmptyState(
                icon: Icons.grid_view,
                message: 'No grid set up yet for this wall.',
              ),
              CaptureSessionLoaded() => _CoverageReviewContent(
                state: state,
                siteId: siteId,
                buildingId: buildingId,
                floorId: floorId,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _CoverageReviewContent extends StatelessWidget {
  const _CoverageReviewContent({
    required this.state,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
  });

  final CaptureSessionLoaded state;
  final String siteId;
  final String buildingId;
  final String floorId;

  @override
  Widget build(BuildContext context) {
    final grid = state.grid!;
    final incomplete = !grid.isComplete;

    return Column(
      children: [
        CaptureScreenHeader(
          title: 'Coverage review',
          subtitle:
              '${state.wall.name} · ${grid.filledCount}/${grid.cells.length} cells covered',
          onBack: () => context.safePop(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GridCaptureMetrics.horizontalPadding,
            ),
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid.cols,
                mainAxisSpacing: GridCaptureMetrics.gap,
                crossAxisSpacing: GridCaptureMetrics.gap,
                childAspectRatio: 1,
              ),
              itemCount: grid.cells.length,
              itemBuilder: (context, index) {
                final row = index ~/ grid.cols + 1;
                final col = index % grid.cols + 1;
                return GridCellTile(
                  label: 'R${row}C$col',
                  photoCount: grid.cells[index].photoCount,
                  mode: GridCellMode.review,
                );
              },
            ),
          ),
        ),
        if (incomplete)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              GridCaptureMetrics.horizontalPadding,
              0,
              GridCaptureMetrics.horizontalPadding,
              AppSpacing.md,
            ),
            child: _IncompleteBanner(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GridCaptureMetrics.horizontalPadding,
            0,
            GridCaptureMetrics.horizontalPadding,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              if (grid.filledCount > 0) ...[
                SecondaryActionButton(
                  label: 'Preview coverage',
                  icon: Icons.visibility_outlined,
                  onTap: () => _previewCoverage(context, grid),
                ),
                const SizedBox(height: GridCaptureMetrics.gap),
              ],
              PrimaryActionButton(
                label: 'Save',
                enabled: grid.isComplete,
                onTap: () {
                  context.read<CaptureSessionCubit>().saveFull();
                  context.go(
                    '/sites/$siteId/buildings/$buildingId/floors/$floorId',
                  );
                },
              ),
              const SizedBox(height: GridCaptureMetrics.gap),
              SecondaryActionButton(
                label: 'Save partial',
                borderColor: WallStatus.inProgress.meta.color,
                textColor: AppColors.onWarningContainer,
                onTap: () {
                  context.read<CaptureSessionCubit>().savePartial();
                  context.go(
                    '/sites/$siteId/buildings/$buildingId/floors/$floorId',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _previewCoverage(BuildContext context, GridState grid) async {
    final request = GridPreviewRequest(
      rows: grid.rows,
      cols: grid.cols,
      cellShotPaths: grid.cells
          .map((cell) => cell.shotPaths.isEmpty ? null : cell.shotPaths.first)
          .toList(),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final imageBytes = await compute(composeGridPreview, request);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GridPreviewScreen(imageBytes: imageBytes),
      ),
    );
  }
}

class _IncompleteBanner extends StatelessWidget {
  const _IncompleteBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning,
            size: 18,
            color: AppColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Some cells still need photos — you can save partial progress.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
