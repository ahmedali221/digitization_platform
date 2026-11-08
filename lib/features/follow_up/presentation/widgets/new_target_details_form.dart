import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/new_target_details.dart';

/// The code a new target goes by in the studio, and what it shows. A problem
/// with either is only pointed out once that field has been typed in.
class NewTargetDetailsForm extends StatefulWidget {
  const NewTargetDetailsForm({
    super.key,
    required this.details,
    required this.conflict,
    required this.onCodeChanged,
    required this.onDescriptionChanged,
  });

  static const int _descriptionMinLines = 3;
  static const int _descriptionMaxLines = 8;

  final NewTargetDetails details;

  /// Why the code can't be used, such as another target already having it.
  final String? conflict;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<NewTargetDetailsForm> createState() => _NewTargetDetailsFormState();
}

class _NewTargetDetailsFormState extends State<NewTargetDetailsForm> {
  late final TextEditingController _code = TextEditingController(text: widget.details.code);
  late final TextEditingController _description = TextEditingController(text: widget.details.description);
  bool _codeTouched = false;
  bool _descriptionTouched = false;

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          textInputAction: TextInputAction.next,
          maxLength: NewTargetDetails.maxCodeLength,
          decoration: InputDecoration(
            labelText: 'Code',
            helperText: 'How the studio will know it, such as W-12-A.',
            errorText: widget.conflict ?? (_codeTouched ? details.codeError : null),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _codeTouched = true);
            widget.onCodeChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _description,
          keyboardType: TextInputType.multiline,
          minLines: NewTargetDetailsForm._descriptionMinLines,
          maxLines: NewTargetDetailsForm._descriptionMaxLines,
          maxLength: NewTargetDetails.maxDescriptionLength,
          decoration: InputDecoration(
            labelText: 'Description',
            helperText: 'What it shows and where it is.',
            alignLabelWithHint: true,
            errorText: _descriptionTouched ? details.descriptionError : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _descriptionTouched = true);
            widget.onDescriptionChanged(value);
          },
        ),
      ],
    );
  }
}
