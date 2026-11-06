import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/target_width.dart';
import '../../domain/repositories/follow_up_repository.dart';
import 'upload_status_chip.dart';

/// A small tag saying which of two pictures is which, so nobody has to work out
/// from the layout whether they're looking at the old image or the new one.
class PhotoTag extends StatelessWidget {
  const PhotoTag({super.key, required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isNew ? AppColors.successContainer : AppColors.hoverSurface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        isNew ? 'New' : 'Old',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isNew ? AppColors.onSuccessContainer : AppColors.textSecondaryIcon,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The image in use now, from the package.
class OldPhoto extends StatelessWidget {
  const OldPhoto({super.key, required this.path, required this.caption});

  final String path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PhotoTag(isNew: false),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(caption, style: Theme.of(context).textTheme.titleSmall)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Image.file(File(path), cacheWidth: 1000),
        ),
      ],
    );
  }
}

/// A photograph taken from this package, with what became of it. It shows the
/// small copy kept for this, since the full photograph is deleted once sent.
class NewPhoto extends StatelessWidget {
  const NewPhoto({super.key, required this.upload});

  final FollowUpUploadRecord upload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notes = [
      if (upload.physicalWidthM != null) 'Width ${TargetWidth.format(upload.physicalWidthM!)}',
      if (upload.rejectReason != null) upload.rejectReason!,
      ...upload.reasons,
      if (upload.status == FollowUpUploadRecord.statusFailed && upload.lastError != null) upload.lastError!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [const PhotoTag(isNew: true), UploadStatusChip(upload: upload)],
        ),
        const SizedBox(height: AppSpacing.xs),
        FutureBuilder<String?>(
          future: GetIt.instance<FollowUpRepository>().photoPath(upload),
          builder: (context, snapshot) {
            final path = snapshot.data;
            if (path == null) return const SizedBox.shrink();
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: Image.file(File(path), cacheWidth: 1000),
            );
          },
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted)),
          ),
      ],
    );
  }
}
