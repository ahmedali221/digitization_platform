import 'package:flutter/material.dart';

import '../../../../core/domain/entities/object_metadata.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// What is known about a museum object, as label and value pairs. Draws
/// nothing when nothing is known.
class ObjectMetadataSummary extends StatelessWidget {
  const ObjectMetadataSummary({super.key, required this.metadata});

  final ObjectMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (label: 'Inventory number', value: metadata.inventoryNumber),
      (label: 'Material', value: metadata.material),
      (label: 'Period / dynasty', value: metadata.period),
      (label: 'Size (H × W × D, cm)', value: _dimensions),
    ].where((row) => row.value != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                Text(
                  row.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                Text(
                  row.value!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String? get _dimensions {
    if (!metadata.hasDimensions) return null;
    return [
      metadata.heightCm,
      metadata.widthCm,
      metadata.depthCm,
    ].map(_formatDimension).join(' × ');
  }

  /// Whole numbers without a trailing ".0"; a missing dimension as a dash.
  String _formatDimension(double? value) {
    if (value == null) return '—';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}
