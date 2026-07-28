import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/wall.dart';
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

/// Lets the operator change an already-initialized grid's rows/cols
/// (FLUTTER_MOBILE_PLAN.md's grid-capture flow doesn't stop at whatever
/// shape was picked at init time) — mirrors the web dashboard's "Resize
/// Grid" (`WallGridService::initializeOrResize`): cells that still exist
/// after the resize keep their photos, and a shrink that would drop a
/// filled cell is refused rather than silently discarding captured work.
class GridReshapePage extends StatelessWidget {
  const GridReshapePage({
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
              CaptureSessionLoaded(:final grid?) => _GridReshapeForm(
                grid: grid,
                wallName: wallName,
                onBack: () => context.safePop(),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _GridReshapeForm extends StatefulWidget {
  const _GridReshapeForm({
    required this.grid,
    required this.wallName,
    required this.onBack,
  });

  final GridState grid;
  final String wallName;
  final VoidCallback onBack;

  @override
  State<_GridReshapeForm> createState() => _GridReshapeFormState();
}

class _GridReshapeFormState extends State<_GridReshapeForm> {
  static const _minDimension = 1;
  static const _maxDimension = 10;
  static const _maxCells = 100;

  late int _rows = widget.grid.rows;
  late int _cols = widget.grid.cols;

  bool _wouldLoseCapturedCells(int rows, int cols) {
    final grid = widget.grid;
    if (rows >= grid.rows && cols >= grid.cols) return false;
    for (var i = 0; i < grid.cells.length; i++) {
      if (!grid.cells[i].hasPhotos) continue;
      final row = i ~/ grid.cols;
      final col = i % grid.cols;
      if (row >= rows || col >= cols) return true;
    }
    return false;
  }

  void _adjust({int rowDelta = 0, int colDelta = 0}) {
    final nextRows = (_rows + rowDelta).clamp(_minDimension, _maxDimension);
    final nextCols = (_cols + colDelta).clamp(_minDimension, _maxDimension);
    if (nextRows * nextCols > _maxCells) return;
    setState(() {
      _rows = nextRows;
      _cols = nextCols;
    });
  }

  void _apply(BuildContext context, int rows, int cols) {
    if (_wouldLoseCapturedCells(rows, cols)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Can't shrink the grid: some cells being removed already have photos.",
          ),
        ),
      );
      return;
    }

    final result = context.read<CaptureSessionCubit>().reshapeGrid(
      rows,
      cols,
    );
    if (!context.mounted) return;

    if (result == GridReshapeResult.blockedShrinkHasPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Can't shrink the grid: some cells being removed already have photos.",
          ),
        ),
      );
      return;
    }

    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final customLosesCells = _wouldLoseCapturedCells(_rows, _cols);

    return Column(
      children: [
        CaptureScreenHeader(
          title: 'Reshape grid',
          subtitle:
              '${widget.wallName} · currently ${grid.rows} × ${grid.cols} '
              '(${grid.filledCount}/${grid.cells.length} cells captured)',
          onBack: widget.onBack,
        ),
        Expanded(
          child: SingleChildScrollView(
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
                    onTap: () => _apply(context, preset.rows, preset.cols),
                  ),
                  const SizedBox(height: GridCaptureMetrics.gap),
                ],
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel('CUSTOM'),
                const SizedBox(height: AppSpacing.sm + 2),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.outlineSubtle,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    children: [
                      GridStepperRow(
                        label: 'Rows',
                        value: _rows,
                        onIncrement: () => _adjust(rowDelta: 1),
                        onDecrement: () => _adjust(rowDelta: -1),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GridStepperRow(
                        label: 'Columns',
                        value: _cols,
                        onIncrement: () => _adjust(colDelta: 1),
                        onDecrement: () => _adjust(colDelta: -1),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_rows * _cols} cells total',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                color: AppColors.onSurfaceMuted,
                              ),
                        ),
                      ),
                      if (customLosesCells) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ShrinkWarning(),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryActionButton(
                        label: 'Apply',
                        enabled: !customLosesCells,
                        onTap: () => _apply(context, _rows, _cols),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShrinkWarning extends StatelessWidget {
  const _ShrinkWarning();

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
          const Icon(Icons.warning, size: 18, color: AppColors.onWarningContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'This would remove cells that already have photos.',
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
