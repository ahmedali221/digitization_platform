import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/captured_photo_thumbnail.dart';
import '../../domain/entities/object_capture.dart';

/// A free photograph beside the description the operator gives it. The
/// description is what tells the dashboard what the picture shows, so the
/// field says so while it is empty.
class CommentedPhotoCard extends StatefulWidget {
  const CommentedPhotoCard({
    super.key,
    required this.photo,
    required this.onOpen,
    required this.onCommentChanged,
  });

  final ObjectPhoto photo;
  final VoidCallback onOpen;
  final ValueChanged<String> onCommentChanged;

  @override
  State<CommentedPhotoCard> createState() => _CommentedPhotoCardState();
}

class _CommentedPhotoCardState extends State<CommentedPhotoCard> {
  // Seeded once: every keystroke is stored and comes back through the
  // capture stream, and writing that back into the field would move the
  // cursor while the operator is still typing.
  late final TextEditingController _comment = TextEditingController(
    text: widget.photo.comment,
  );

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMissing = widget.photo.comment.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: isMissing
              ? AppColors.onWarningContainer
              : AppColors.outlineSubtle,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapturedPhotoThumbnail(path: widget.photo.path, onTap: widget.onOpen),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: widget.onCommentChanged,
              decoration: InputDecoration(
                labelText: 'What does this show?',
                hintText: 'e.g. Inscription on the back pillar',
                helperText: isMissing ? 'Needed before saving' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
