import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/follow_up_upload_record.dart';
import 'new_target_card.dart';

/// The way to add a target the site had no profile for, and those already
/// added, at the top of the targets list.
class NewTargetsSection extends StatelessWidget {
  const NewTargetsSection({
    super.key,
    required this.newTargets,
    required this.photoPathOf,
    required this.onAdd,
  });

  final List<FollowUpUploadRecord> newTargets;
  final Future<String?> Function(FollowUpUploadRecord upload) photoPathOf;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add a new target'),
              onPressed: onAdd,
            ),
          ),
          if (newTargets.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
                child: Text('New targets', style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            SliverList.separated(
              itemCount: newTargets.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final upload = newTargets[index];
                return NewTargetCard(
                  key: ValueKey(upload.token),
                  upload: upload,
                  photoPath: photoPathOf(upload),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
