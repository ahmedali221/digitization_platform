import 'package:flutter/material.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';

/// Chooses what is being added: a wall, a painting, a statue… One chip per
/// type, wrapping onto as many lines as the screen needs.
class ObjectTypePicker extends StatelessWidget {
  const ObjectTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ObjectType selected;
  final ValueChanged<ObjectType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final type in ObjectType.values)
          ChoiceChip(
            avatar: Icon(
              type.meta.icon,
              size: AppSpacing.lg,
              color: type == selected ? Colors.white : AppColors.iconMuted,
            ),
            label: Text(type.meta.label),
            selected: type == selected,
            showCheckmark: false,
            selectedColor: AppColors.seed,
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: type == selected ? Colors.white : AppColors.textPrimary,
            ),
            onSelected: (_) => onSelected(type),
          ),
      ],
    );
  }
}
