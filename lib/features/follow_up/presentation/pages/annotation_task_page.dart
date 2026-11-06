import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/follow_up_uploads.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/services/shot_processing.dart';
import '../widgets/labelled_photo.dart';
import '../widgets/outlined_wall_picture.dart';
import 'crop_photo_page.dart';
import 'follow_up_camera_page.dart';
import 'follow_up_grid_page.dart';
import 'shot_review_page.dart';

/// Where an annotation is on its wall, why it needs a new photograph, and the
/// way to take one: shots, pick the best, crop to the text; or a grid, for text
/// too long for one sharp shot, which the dashboard stitches. Once one is taken,
/// it shows beside the old close-up, labelled, with what became of it.
class AnnotationTaskPage extends StatefulWidget {
  const AnnotationTaskPage({super.key, required this.package, required this.annotation});

  final FollowUpPackage package;
  final FollowUpAnnotation annotation;

  @override
  State<AnnotationTaskPage> createState() => _AnnotationTaskPageState();
}

class _AnnotationTaskPageState extends State<AnnotationTaskPage> {
  final FollowUpRepository _repository = GetIt.instance<FollowUpRepository>();
  bool _working = false;

  late final Future<({String? picture, String? closeup})> _paths = _loadPaths();

  @override
  void initState() {
    super.initState();
    unawaited(_repository.sync());
  }

  Future<({String? picture, String? closeup})> _loadPaths() async {
    final annotation = widget.annotation;
    final siteId = widget.package.siteId;
    return (
      picture: annotation.picture == null ? null : await _repository.filePath(siteId, annotation.picture!.key),
      closeup: annotation.closeupKey == null ? null : await _repository.filePath(siteId, annotation.closeupKey!),
    );
  }

  Future<void> _takePhotos() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final siteId = widget.package.siteId;
    final folder = await _repository.newShotsFolder(siteId);

    final shots = await navigator.push<List<String>>(
      MaterialPageRoute(builder: (_) => FollowUpCameraPage(title: widget.annotation.referenceCode, folder: folder)),
    );
    if (shots == null || shots.isEmpty) return;

    final chosen = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => ShotReviewPage(shots: shots)),
    );
    if (chosen == null) return;

    final box = await navigator.push<CropBox>(
      MaterialPageRoute(builder: (_) => CropPhotoPage(photoPath: chosen)),
    );
    if (box == null) return;

    setState(() => _working = true);
    try {
      final cropped = p.join(folder, 'cropped.jpg');
      await compute(
        cropPhoto,
        CropRequest(
          sourcePath: chosen,
          targetPath: cropped,
          left: box.left,
          top: box.top,
          right: box.right,
          bottom: box.bottom,
        ),
      );
      await _repository.queueAnnotationCapture(
        package: widget.package,
        annotation: widget.annotation,
        photoPath: cropped,
      );
      await Directory(folder).delete(recursive: true);
      messenger.showSnackBar(const SnackBar(content: Text('Saved. It will be sent when there is a connection.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('The photograph could not be saved: $error')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _takeGrid() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final folder = await _repository.newShotsFolder(widget.package.siteId);

    try {
      final grid = await navigator.push<FollowUpGridResult>(
        MaterialPageRoute(
          builder: (_) => FollowUpGridPage(title: widget.annotation.referenceCode, folder: folder),
        ),
      );
      if (grid == null) return;

      setState(() => _working = true);
      await _repository.queueAnnotationGrid(
        package: widget.package,
        annotation: widget.annotation,
        rows: grid.rows,
        cols: grid.cols,
        photos: grid.photos,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Saved. It will be sent when there is a connection.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('The photographs could not be saved: $error')));
    } finally {
      await deleteGridFolder(folder);
      if (mounted) setState(() => _working = false);
    }
  }

  /// Can't wait in a queue: someone is at the wall deciding whether to retake it.
  Future<void> _decide(FollowUpUploadRecord upload, {required bool use}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await _repository.decideGrid(upload, use: use);
    } on AppException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('That needs a connection, and did not go through: ${error.failure.message}')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final annotation = widget.annotation;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(annotation.referenceCode)),
      body: SafeArea(
        child: FutureBuilder(
          future: _paths,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LoadingIndicator();
            final paths = snapshot.data!;
            return ListenableBuilder(
              listenable: _repository.uploadsChanged,
              builder: (context, _) {
            // The newest is the one in use: annotations apply by themselves.
            final newPhotos = newPhotosOf(
              widget.package,
              _repository.uploads(widget.package.siteId),
              kind: FollowUpUploadRecord.kindAnnotation,
              itemKey: annotation.id.toString(),
            );
            return RefreshIndicator(
              onRefresh: _repository.sync,
              child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(annotation.wall.name, style: textTheme.titleMedium),
                if (annotation.wall.location.isNotEmpty)
                  Text(annotation.wall.location, style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted)),
                const SizedBox(height: AppSpacing.md),
                if (annotation.picture != null && paths.picture != null) ...[
                  Text('Where it is on the wall', style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedWallPicture(
                    path: paths.picture!,
                    picture: annotation.picture!,
                    polygon: annotation.polygon,
                  ),
                ],
                if (paths.closeup != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OldPhoto(path: paths.closeup!, caption: 'What the wall picture shows'),
                ],
                if (newPhotos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  NewPhoto(key: ValueKey('${newPhotos.first.token}:${newPhotos.first.previewPath}'), upload: newPhotos.first),
                  if (newPhotos.first.serverStatus == 'needs_decision') ...[
                    const SizedBox(height: AppSpacing.md),
                    _GridDecision(
                      upload: newPhotos.first,
                      enabled: !_working,
                      onDecide: (use) => _decide(newPhotos.first, use: use),
                    ),
                  ],
                ],
                if (annotation.reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Why it needs a new photograph', style: textTheme.titleSmall),
                  for (final reason in annotation.reasons)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(reason, style: textTheme.bodyMedium),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  newPhotos.isEmpty ? 'Take a new photograph' : 'Take another photograph',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryActionButton(
                  icon: Icons.photo_camera,
                  label: _working ? 'Saving…' : 'One photo',
                  enabled: !_working,
                  onTap: _takePhotos,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.grid_on),
                  label: const Text('Grid, for long text'),
                  onPressed: _working ? null : _takeGrid,
                ),
              ],
            ),
            );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The dashboard could only join part of a grid. Nothing has changed yet: the
/// picture above is what using it would give, and it's this person's choice.
class _GridDecision extends StatelessWidget {
  const _GridDecision({required this.upload, required this.enabled, required this.onDecide});

  final FollowUpUploadRecord upload;
  final bool enabled;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context) {
    final missing = upload.failedCells.map((cell) => 'R${cell.row + 1}C${cell.col + 1}').join(', ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This did not join: $missing. The picture above is without it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => onDecide(false) : null,
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: enabled ? () => onDecide(true) : null,
                  child: const Text('Use this picture'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
