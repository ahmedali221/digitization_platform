import 'package:flutter/material.dart';

import '../camera/camera_widgets.dart';
import '../theme/app_colors.dart';
import 'confirm_dialog.dart';
import 'photo_preview_dialog.dart';
import 'primary_action_button.dart';

enum CapturedPhotoDecision { delete, retake }

/// Shows a photograph not yet saved, full screen, and returns what the operator
/// decided to do with it, or null if they only looked. [canRetake] is for screens
/// away from the camera: on the camera itself, the shutter is already the retake.
Future<CapturedPhotoDecision?> reviewCapturedPhoto(
  BuildContext context,
  String path, {
  String? label,
  bool canRetake = false,
}) {
  return PhotoPreviewDialog.show<CapturedPhotoDecision>(
    context,
    (_) => _CapturedPhotoReview(path: path, label: label, canRetake: canRetake),
  );
}

class _CapturedPhotoReview extends StatelessWidget {
  const _CapturedPhotoReview({
    required this.path,
    required this.label,
    required this.canRetake,
  });

  final String path;
  final String? label;
  final bool canRetake;

  Future<void> _confirmDelete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this photograph?',
      message:
          'It has not been sent, and can\'t be brought back. You can take another straight away.',
      confirmLabel: 'Delete',
    );
    if (confirmed) navigator.pop(CapturedPhotoDecision.delete);
  }

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return PhotoPreviewDialog(
      path: path,
      badge: label == null ? null : CameraPill(label: label),
      actions: [
        SecondaryActionButton(
          icon: Icons.delete_outline,
          label: 'Delete',
          borderColor: AppColors.dangerContainer,
          textColor: AppColors.dangerContainer,
          onTap: () => _confirmDelete(context),
        ),
        if (canRetake)
          PrimaryActionButton(
            icon: Icons.photo_camera,
            label: 'Retake',
            onTap: () =>
                Navigator.of(context).pop(CapturedPhotoDecision.retake),
          ),
      ],
    );
  }
}
