import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

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
import '../widgets/grid_cell_tile.dart';

class GridCapturePage extends StatelessWidget {
  const GridCapturePage({
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
              CaptureSessionLoaded(grid: null) => EmptyState(
                icon: Icons.grid_view,
                message: 'No grid set up yet for this wall.',
                actionLabel: 'Set up grid',
                onAction: () => context.pushReplacement(
                  '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/$wallId/grid-init',
                ),
              ),
              CaptureSessionLoaded() => _GridCaptureContent(
                state: state,
                siteId: siteId,
                buildingId: buildingId,
                floorId: floorId,
                wallId: wallId,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _GridCaptureContent extends StatelessWidget {
  const _GridCaptureContent({
    required this.state,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  final CaptureSessionLoaded state;
  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  @override
  Widget build(BuildContext context) {
    final grid = state.grid!;
    return Column(
      children: [
        CaptureScreenHeader(
          title: state.wall.name,
          subtitle: '${grid.filledCount}/${grid.cells.length} cells covered',
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
                final shotPaths = grid.cells[index].shotPaths;
                return GridCellTile(
                  label: 'R${row}C$col',
                  photoCount: grid.cells[index].photoCount,
                  thumbnailPath: shotPaths.isEmpty ? null : shotPaths.first,
                  isSelected: state.activeCellId == index,
                  onTap: () {
                    context.read<CaptureSessionCubit>().openCell(index);
                    context.push(
                      '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/$wallId/camera?cell=$index',
                    );
                  },
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GridCaptureMetrics.horizontalPadding,
            AppSpacing.md,
            GridCaptureMetrics.horizontalPadding,
            GridCaptureMetrics.horizontalPadding,
          ),
          child: PrimaryActionButton(
            label: 'Review coverage',
            enabled: grid.filledCount > 0,
            onTap: () => context.push(
              '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/$wallId/coverage-review',
            ),
          ),
        ),
      ],
    );
  }
}
