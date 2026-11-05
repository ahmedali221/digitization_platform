import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/services/shot_processing.dart';
import '../widgets/outlined_wall_picture.dart';
import 'crop_photo_page.dart';
import 'follow_up_camera_page.dart';
import 'shot_review_page.dart';

/// Where an annotation is on its wall, why it needs a new photograph, and the
/// way to take one: shots, pick the best, crop to the text.
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
      if (mounted) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('The photograph could not be saved: $error')));
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
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(annotation.wall.name, style: textTheme.titleMedium),
                if (annotation.wall.location.isNotEmpty)
                  Text(annotation.wall.location, style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted)),
                const SizedBox(height: AppSpacing.md),
                if (annotation.picture != null && paths.picture != null)
                  OutlinedWallPicture(
                    path: paths.picture!,
                    picture: annotation.picture!,
                    polygon: annotation.polygon,
                  ),
                if (paths.closeup != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Close-up of what the wall picture shows', style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Image.file(File(paths.closeup!)),
                  ),
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
                PrimaryActionButton(
                  icon: Icons.photo_camera,
                  label: _working ? 'Saving…' : 'Take new photographs',
                  enabled: !_working,
                  onTap: _takePhotos,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
