import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The small capitalised caption above a field on the add-item form.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.text, {super.key});

  static const double _letterSpacing = 0.5;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onSurfaceMuted,
        letterSpacing: _letterSpacing,
      ),
    );
  }
}
