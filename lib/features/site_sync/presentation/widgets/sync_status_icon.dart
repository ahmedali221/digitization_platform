import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../sync_queue/domain/entities/sync_item.dart';
import '../../../sync_queue/domain/repositories/sync_queue_repository.dart';

/// The header's sync icon, overlaid with a live count of items still
/// awaiting upload (queued/uploading/failed) — the operator's only
/// at-a-glance signal that captures haven't reached the server yet. That
/// window matters on iOS: a true reinstall (as opposed to an in-place
/// update) wipes local storage entirely, so anything still counted here
/// would be lost for good if it happened before the count reached zero.
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncItem>>(
      stream: GetIt.instance<SyncQueueRepository>().watchQueue(),
      builder: (context, snapshot) {
        final pending =
            snapshot.data
                ?.where((item) => item.status != SyncItemStatus.confirmed)
                .length ??
            0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(icon: Icons.sync, onTap: onTap),
            if (pending > 0)
              Positioned(right: 0, top: 0, child: _CountDot(count: pending)),
          ],
        );
      },
    );
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: AppColors.onDangerContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}
