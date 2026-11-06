import 'dart:async';

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
import '../widgets/captured_photo_review.dart';
import '../widgets/captured_photo_thumbnail.dart';
import '../widgets/save_failed_notice.dart';

/// A grid of photographs of something too long for one sharp shot: choose its
/// size, photograph each cell, check they overlap, and send them to be stitched.
///
/// The photographs stay in [folder], in the app's own storage, with no copy in
/// the gallery, which is the caller's to delete once this page has closed. It
/// stays open until [onSend] succeeds, so that a failure costs no photographs,
/// and pops with true when it has.
class FollowUpGridPage extends StatelessWidget {
  const FollowUpGridPage({super.key, required this.title, required this.folder, required this.onSend});

  final String title;
  final String folder;
  final Future<void> Function(FollowUpGridState grid) onSend;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FollowUpGridCubit(GetIt.instance<CellQualityAnalyzer>()),
      child: _GridBody(title: title, folder: folder, onSend: onSend),
    );
  }
}

String _cellName(int cell, int cols) => 'R${cell ~/ cols + 1}C${cell % cols + 1}';

class _GridBody extends StatelessWidget {
  const _GridBody({required this.title, required this.folder, required this.onSend});

  final String title;
  final String folder;
  final Future<void> Function(FollowUpGridState grid) onSend;

  Future<void> _send(BuildContext context) async {
    final cubit = context.read<FollowUpGridCubit>();
    final navigator = Navigator.of(context);
    if (await cubit.send(onSend)) navigator.pop(true);
  }

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
            // Leaving deletes the folder that the photographs are being copied from.
            if (!didPop && !state.sending) unawaited(_confirmLeaving(context));
          },
          child: Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: state.photos.isEmpty
                  ? _ChooseSize(state: state, onStart: () => _openCamera(context))
                  : _Review(
                      state: state,
                      onOpenCamera: () => _openCamera(context),
                      onSend: () => _send(context),
                    ),
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

/// Every cell and how its neighbours join, before anything is sent. A cell with
/// a photograph opens it, to delete or retake; an empty one opens the camera.
class _Review extends StatelessWidget {
  const _Review({required this.state, required this.onOpenCamera, required this.onSend});

  final FollowUpGridState state;
  final VoidCallback onOpenCamera;
  final VoidCallback onSend;

  void _photograph(FollowUpGridCubit cubit, int cell) {
    cubit.select(cell);
    onOpenCamera();
  }

  Future<void> _openCell(BuildContext context, int cell) async {
    final cubit = context.read<FollowUpGridCubit>();
    final path = state.photos[cell];
    if (path == null) return _photograph(cubit, cell);

    final decision = await reviewCapturedPhoto(
      context,
      path,
      label: _cellName(cell, state.cols),
      canRetake: true,
    );
    switch (decision) {
      case CapturedPhotoDecision.delete:
        await cubit.removePhoto(cell);
      case CapturedPhotoDecision.retake:
        _photograph(cubit, cell);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onTap: state.sending ? null : () => _openCell(context, cell),
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
                    'Tap one to check or retake it.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (state.sendError != null) ...[
                SaveFailedNotice(
                  message:
                      'The photographs could not be saved, but they are still here. '
                      'Try again. (${state.sendError})',
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
                  label: state.sending
                      ? 'Saving…'
                      : weak.isEmpty
                      ? 'Send to be stitched'
                      : 'Send anyway',
                  enabled: !state.sending,
                  onTap: onSend,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The camera, with a strip of the grid's cells under it. It moves to the next
/// empty cell by itself, and closes back to the review when none are left. The
/// thumbnail beside the shutter opens a photograph, to delete it and take another.
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

  /// The volume key and Bluetooth remote still reach here under a preview or a
  /// confirmation, where a photograph would be taken unseen, and the last cell's
  /// would close that dialog instead of this page.
  Future<void> _shoot() async {
    if (ModalRoute.isCurrentOf(context) ?? false) await _camera.capture(_keep);
  }

  Future<void> _keep(XFile file) async {
    final cubit = context.read<FollowUpGridCubit>();
    final navigator = Navigator.of(context);
    final path = p.join(widget.folder, 'cell_${cubit.state.activeCell}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.saveTo(path);

    final wasIncomplete = !cubit.state.isComplete;
    unawaited(cubit.addPhoto(path));
    if (wasIncomplete && cubit.state.isComplete && mounted) navigator.pop();
  }

  Future<void> _reviewCell(FollowUpGridState state, int cell) async {
    final cubit = context.read<FollowUpGridCubit>();
    final decision = await reviewCapturedPhoto(
      context,
      state.photos[cell]!,
      label: _cellName(cell, state.cols),
    );
    if (decision == CapturedPhotoDecision.delete) await cubit.removePhoto(cell);
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
    final reviewableCell = state.reviewableCell;
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: reviewableCell == null
                          ? null
                          : CapturedPhotoThumbnail(
                              path: state.photos[reviewableCell]!,
                              label: _cellName(reviewableCell, state.cols),
                              onTap: _camera.capturing ? null : () => _reviewCell(state, reviewableCell),
                            ),
                    ),
                  ),
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
