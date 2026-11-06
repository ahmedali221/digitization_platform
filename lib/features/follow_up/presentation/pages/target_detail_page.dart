import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/follow_up_uploads.dart';
import '../../domain/entities/target_match_result.dart';
import '../../domain/entities/target_width.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/services/target_video_matcher.dart';
import '../widgets/labelled_photo.dart';
import 'follow_up_camera_page.dart';
import 'shot_review_page.dart';
import 'target_width_page.dart';

/// One AR target and the way to replace it. The photograph goes whole, with no
/// crop: the dashboard's reviewer straightens it from the untouched photograph,
/// and a crop here could cut off a corner of the wall for good. Several can be
/// sent: each shows here as New, with what the dashboard and the studio made of it.
class TargetDetailPage extends StatefulWidget {
  const TargetDetailPage({super.key, required this.package, required this.target});

  final FollowUpPackage package;
  final FollowUpTarget target;

  @override
  State<TargetDetailPage> createState() => _TargetDetailPageState();
}

class _TargetDetailPageState extends State<TargetDetailPage> {
  final FollowUpRepository _repository = GetIt.instance<FollowUpRepository>();
  bool _working = false;

  late final Future<({String image, String? frame})> _paths = _loadPaths();

  @override
  void initState() {
    super.initState();
    unawaited(_repository.sync());
  }

  double? get _currentWidth => currentTargetWidth(
    widget.target,
    _repository.uploads(widget.package.siteId),
    packageCreatedAt: widget.package.createdAt,
  );

  Future<({String image, String? frame})> _loadPaths() async {
    final siteId = widget.package.siteId;
    final frameKey = widget.target.videoFrameKey;
    return (
      image: await _repository.filePath(siteId, widget.target.imageKey),
      frame: frameKey == null ? null : await _repository.filePath(siteId, frameKey),
    );
  }

  /// Measures the target as it stands, with no new photograph.
  Future<void> _measureOnly(String imagePath) async {
    final messenger = ScaffoldMessenger.of(context);
    final width = await Navigator.of(context).push<TargetWidth>(
      MaterialPageRoute(builder: (_) => TargetWidthPage(title: widget.target.label, imagePath: imagePath)),
    );
    if (width == null) return;

    try {
      await _repository.queueTargetWidth(package: widget.package, target: widget.target, width: width);
      messenger.showSnackBar(SnackBar(content: Text('Width saved: ${TargetWidth.format(width.meters)}.')));
      if (mounted) setState(() {});
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('The width could not be saved: $error')));
    }
  }

  Future<void> _replace(String imagePath, String? framePath) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final folder = await _repository.newShotsFolder(widget.package.siteId);

    while (mounted) {
      final shots = await navigator.push<List<String>>(
        MaterialPageRoute(builder: (_) => FollowUpCameraPage(title: widget.target.label, folder: folder)),
      );
      if (shots == null || shots.isEmpty) return;

      final chosen = await navigator.push<String>(
        MaterialPageRoute(builder: (_) => ShotReviewPage(shots: shots)),
      );
      if (chosen == null) return;

      setState(() => _working = true);
      try {
        final match = framePath == null
            ? null
            : await compute(
                matchTargetToVideoFrame,
                TargetMatchRequest(photoPath: chosen, framePath: framePath),
              );

        var warningConfirmed = false;
        if (match != null && !match.matched) {
          if (!mounted) return;
          final send = await _confirmMismatch(chosen, framePath!, match);
          if (send != true) continue;
          warningConfirmed = true;
        }

        // Last, so a retake never costs a measurement.
        final width = await navigator.push<TargetWidth>(
          MaterialPageRoute(
            builder: (_) => TargetWidthPage(
              title: widget.target.label,
              imagePath: imagePath,
              discardsPhotograph: true,
              currentMeters: _currentWidth,
            ),
          ),
        );
        if (width == null) return;

        await _repository.queueTargetCapture(
          package: widget.package,
          target: widget.target,
          photoPath: chosen,
          match: match,
          warningConfirmed: warningConfirmed,
          width: width,
        );
        await Directory(folder).delete(recursive: true);
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved. It will be reviewed on the dashboard before anything changes.')),
        );
        return;
      } catch (error) {
        messenger.showSnackBar(SnackBar(content: Text('The photograph could not be saved: $error')));
        return;
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }
  }

  Future<bool?> _confirmMismatch(String photoPath, String framePath, TargetMatchResult match) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('This looks different from the video'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                match.frameFound
                    ? 'Part of what the video shows is outside this photograph. Include the whole of it.'
                    : 'This photograph could not be matched to the video. Check that it is the same wall.',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Your photograph'),
              const SizedBox(height: AppSpacing.xs),
              Image.file(File(photoPath), cacheWidth: 800),
              const SizedBox(height: AppSpacing.md),
              const Text('The video'),
              const SizedBox(height: AppSpacing.xs),
              Image.file(File(framePath), cacheWidth: 800),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send anyway'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retake'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(target.label)),
      body: SafeArea(
        child: FutureBuilder(
          future: _paths,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LoadingIndicator();
            final paths = snapshot.data!;
            return ListenableBuilder(
              listenable: _repository.uploadsChanged,
              builder: (context, _) {
            final width = _currentWidth;
            final newPhotos = newPhotosOf(
              widget.package,
              _repository.uploads(widget.package.siteId),
              kind: FollowUpUploadRecord.kindTarget,
              itemKey: target.arKey,
            );
            return RefreshIndicator(
              onRefresh: _repository.sync,
              child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(target.place, style: textTheme.titleMedium),
                if (target.description != null && target.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    target.description!,
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OldPhoto(path: paths.image, caption: 'The target in use'),
                for (final photo in newPhotos) ...[
                  const SizedBox(height: AppSpacing.lg),
                  NewPhoto(key: ValueKey(photo.token), upload: photo),
                ],
                if (targetWasReplaced(newPhotos)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This target has been replaced. Download a new package before replacing it again.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer),
                  ),
                ],
                if (paths.frame != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('First frame of its video', style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Image.file(File(paths.frame!)),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Width on the wall', style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                if (width != null)
                  Text(TargetWidth.format(width), style: textTheme.titleMedium)
                else
                  Text(
                    'Width missing. Thoth Guide AI needs the real size of every target.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer),
                  ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.straighten),
                  label: Text(width == null ? 'Measure width' : 'Measure again'),
                  onPressed: _working ? null : () => _measureOnly(paths.image),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Stand square to the wall and include all of what the target shows, with some wall around it. '
                  'Someone will straighten and approve it on the dashboard before anything changes.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryActionButton(
                  icon: Icons.photo_camera,
                  label: _working ? 'Checking against the video…' : 'Replace this target',
                  enabled: !_working,
                  onTap: () => _replace(paths.image, paths.frame),
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
