import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import '../../../../core/camera/camera_widgets.dart';
import '../../../../core/camera/capture_camera_session.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../grid_capture/data/datasources/camera_preferences_local_data_source.dart';
import '../../../grid_capture/domain/services/cell_quality_analyzer.dart';
import '../../../grid_capture/presentation/widgets/camera_grid_navigator.dart';
import '../../../grid_capture/presentation/widgets/grid_cell_tile.dart';
import '../../../grid_capture/presentation/widgets/grid_stepper_row.dart';
import '../../../grid_capture/presentation/widgets/linked_coverage_grid.dart';
import '../cubit/follow_up_grid_cubit.dart';

/// What [FollowUpGridPage] pops with, once every cell has its photograph.
class FollowUpGridResult {
  const FollowUpGridResult({required this.rows, required this.cols, required this.photos});

  final int rows;
  final int cols;

  /// Keyed by cell, row by row.
  final Map<int, String> photos;
}

/// A grid of photographs of something too long for one sharp shot: choose its
/// size, photograph each cell, check they overlap, and send them to be stitched.
///
/// The photographs stay in [folder], in the app's own storage, with no copy in
/// the gallery, which is the caller's to delete afterwards.
class FollowUpGridPage extends StatelessWidget {
  const FollowUpGridPage({super.key, required this.title, required this.folder});

  final String title;
  final String folder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FollowUpGridCubit(GetIt.instance<CellQualityAnalyzer>()),
      child: _GridBody(title: title, folder: folder),
    );
  }
}

String _cellName(int cell, int cols) => 'R${cell ~/ cols + 1}C${cell % cols + 1}';

class _GridBody extends StatelessWidget {
  const _GridBody({required this.title, required this.folder});

  final String title;
  final String folder;

  Future<void> _openCamera(BuildContext context) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: context.read<FollowUpGridCubit>(),
        child: _GridCameraPage(title: title, folder: folder),
      ),
    ),
  );

  Future<void> _confirmLeaving(BuildContext context) async {
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard these photographs?'),
        content: const Text('None of this grid has been sent yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave ?? false) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpGridCubit, FollowUpGridState>(
      builder: (context, state) {
        return PopScope(
          canPop: state.photos.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmLeaving(context));
          },
          child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: state.photos.isEmpty
                  ? _ChooseSize(state: state, onStart: () => _openCamera(context))
                  : _Review(state: state, onOpenCamera: () => _openCamera(context)),
            ),
          ),
        );
      },
    );
  }
}

class _ChooseSize extends StatelessWidget {
  const _ChooseSize({required this.state, required this.onStart});

  final FollowUpGridState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FollowUpGridCubit>();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Divide the text into cells, and overlap each photograph with its neighbours by about a third. '
          'The dashboard joins them. Frame only the text: the joined picture is not cropped afterwards.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        GridStepperRow(
          label: 'Rows',
          value: state.rows,
          onIncrement: () => cubit.resize(rows: state.rows + 1),
          onDecrement: () => cubit.resize(rows: state.rows - 1),
        ),
        GridStepperRow(
          label: 'Columns',
          value: state.cols,
          onIncrement: () => cubit.resize(cols: state.cols + 1),
          onDecrement: () => cubit.resize(cols: state.cols - 1),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${state.cellCount} photographs',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryActionButton(icon: Icons.photo_camera, label: 'Start', onTap: onStart),
      ],
    );
  }
}

/// Every cell and how its neighbours join, before anything is sent. A cell is
/// tapped to photograph it again.
class _Review extends StatelessWidget {
  const _Review({required this.state, required this.onOpenCamera});

  final FollowUpGridState state;
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FollowUpGridCubit>();
    final textTheme = Theme.of(context).textTheme;
    final weak = state.weakLinks;
    final missing = state.cellCount - state.photos.length;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: LinkedCoverageGrid(
            rows: state.rows,
            cols: state.cols,
            linkMetrics: state.link,
            bottomPadding: AppSpacing.lg,
            itemBuilder: (context, cell) {
              final quality = state.quality[cell];
              return GridCellTile(
                label: _cellName(cell, state.cols),
                photoCount: state.photos.containsKey(cell) ? 1 : 0,
                thumbnailPath: state.photos[cell],
                mode: GridCellMode.review,
                qualityTier: quality?.tier,
                qualityScore: quality?.cellScore.round(),
                onTap: () {
                  cubit.select(cell);
                  onOpenCamera();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (weak.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    'Not enough overlap: '
                    '${weak.map((link) => '${_cellName(link.from, state.cols)} and ${_cellName(link.to, state.cols)}').join(', ')}. '
                    'Tap one to photograph it again.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (missing > 0)
                PrimaryActionButton(
                  icon: Icons.photo_camera,
                  label: missing == 1 ? '1 cell left' : '$missing cells left',
                  onTap: onOpenCamera,
                )
              else
                PrimaryActionButton(
                  icon: Icons.upload,
                  label: weak.isEmpty ? 'Send to be stitched' : 'Send anyway',
                  onTap: () => Navigator.of(context).pop(
                    FollowUpGridResult(rows: state.rows, cols: state.cols, photos: state.photos),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The camera, with a strip of the grid's cells under it. It moves to the next
/// empty cell by itself, and closes back to the review when none are left.
class _GridCameraPage extends StatefulWidget {
  const _GridCameraPage({required this.title, required this.folder});

  final String title;
  final String folder;

  @override
  State<_GridCameraPage> createState() => _GridCameraPageState();
}

class _GridCameraPageState extends State<_GridCameraPage> {
  late final CaptureCameraSession _camera;

  final CameraPreferencesLocalDataSource _preferences = GetIt.instance<CameraPreferencesLocalDataSource>();

  @override
  void initState() {
    super.initState();
    _camera = CaptureCameraSession(
      initialFlashModeName: _preferences.getFlashModeName(),
      onFlashModeChanged: (name) => unawaited(_preferences.setFlashModeName(name)),
      onMessage: (message) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
      onShutterPressed: _shoot,
    )..addListener(_onCameraChanged);
    _camera.start();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _shoot() => _camera.capture(_keep);

  Future<void> _keep(XFile file) async {
    final cubit = context.read<FollowUpGridCubit>();
    final navigator = Navigator.of(context);
    final path = p.join(widget.folder, 'cell_${cubit.state.activeCell}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(path);

    final wasIncomplete = !cubit.state.isComplete;
    unawaited(cubit.addPhoto(path));
    if (wasIncomplete && cubit.state.isComplete && mounted) navigator.pop();
  }

  @override
  void dispose() {
    _camera
      ..removeListener(_onCameraChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<FollowUpGridCubit>();
    final state = cubit.state;
    return Scaffold(
      backgroundColor: AppColors.cameraBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CameraViewfinder(
                    loadState: _camera.loadState,
                    errorMessage: _camera.errorMessage,
                    controller: _camera.controller,
                    onScaleStart: _camera.onScaleStart,
                    onScaleUpdate: _camera.onScaleUpdate,
                  ),
                  Positioned(
                    top: AppSpacing.lg,
                    left: AppSpacing.lg,
                    child: CameraRoundButton(
                      icon: Icons.arrow_back,
                      iconColor: Colors.white,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.lg,
                    child: CameraPill(label: '${widget.title} · ${_cellName(state.activeCell, state.cols)}'),
                  ),
                  Positioned(
                    top: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: CameraFlashButton(mode: _camera.flashMode, onTap: _camera.cycleFlash),
                  ),
                  if (_camera.loadState == CameraLoadState.ready)
                    Positioned(
                      bottom: AppSpacing.md,
                      child: CameraZoomPresets(
                        currentZoom: _camera.displayZoom,
                        minimumZoom: _camera.primaryMinimumZoom,
                        maximumZoom: _camera.primaryMaximumZoom,
                        hasUltraWideLens: _camera.canReachUltraWide,
                        onSelect: _camera.selectZoomPreset,
                      ),
                    ),
                ],
              ),
            ),
            CameraGridNavigator(
              grid: GridState(
                rows: state.rows,
                cols: state.cols,
                cells: [
                  for (var cell = 0; cell < state.cellCount; cell++)
                    GridCell(shotPaths: [if (state.photos[cell] != null) state.photos[cell]!]),
                ],
              ),
              activeCellIndex: state.activeCell,
              onCellSelected: cubit.select,
              cellQuality: state.quality,
              enabled: !_camera.capturing,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Spacer(),
                  CameraShutterButton(onTap: _camera.canShoot ? _shoot : null),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: state.photos.isEmpty || _camera.capturing ? null : () => Navigator.of(context).pop(),
                        child: Text('Review (${state.photos.length}/${state.cellCount})'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deletes a grid's folder, for callers once its photographs are queued or dropped.
Future<void> deleteGridFolder(String folder) async {
  final directory = Directory(folder);
  if (await directory.exists()) await directory.delete(recursive: true);
}
