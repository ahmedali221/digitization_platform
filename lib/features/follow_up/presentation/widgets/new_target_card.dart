import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/follow_up_upload_record.dart';
import '../../domain/entities/target_width.dart';
import 'upload_status_chip.dart';

/// A target added at this site, with how far it has got towards being a profile.
class NewTargetCard extends StatelessWidget {
  const NewTargetCard({super.key, required this.upload, required this.photoPath});

  static const double _thumbnailSize = 72;
  static const int _thumbnailCacheWidth = 240;

  final FollowUpUploadRecord upload;

  /// The small copy kept of its photograph, or null once it's gone.
  final Future<String?> photoPath;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted);
    final notes = [
      if (upload.physicalWidthM != null) 'Width ${TargetWidth.format(upload.physicalWidthM!)}',
      if (upload.rejectReason != null) upload.rejectReason!,
      if (upload.status == FollowUpUploadRecord.statusFailed && upload.lastError != null) upload.lastError!,
      if (upload.serverStatus == 'created') 'Download the new package to photograph or measure it again.',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.outlineSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: SizedBox.square(
              dimension: _thumbnailSize,
              child: FutureBuilder<String?>(
                future: photoPath,
                builder: (context, snapshot) => snapshot.data == null
                    ? const ColoredBox(color: AppColors.surfaceNeutral)
                    : Image.file(File(snapshot.data!), fit: BoxFit.cover, cacheWidth: _thumbnailCacheWidth),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(upload.label, style: textTheme.titleSmall),
                if (upload.description != null)
                  Text(upload.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: mutedStyle),
                const SizedBox(height: AppSpacing.xs),
                UploadStatusChip(upload: upload),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(note, style: mutedStyle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
