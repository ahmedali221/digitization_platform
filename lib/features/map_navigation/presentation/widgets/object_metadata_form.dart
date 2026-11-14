import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/entities/object_metadata.dart';
import '../../../../core/theme/app_spacing.dart';
import 'form_field_label.dart';

/// The text an operator types into [ObjectMetadataForm], owned by the page
/// so it outlives the form being hidden and shown as the type changes.
class ObjectMetadataControllers {
  final inventoryNumber = TextEditingController();
  final material = TextEditingController();
  final period = TextEditingController();
  final height = TextEditingController();
  final width = TextEditingController();
  final depth = TextEditingController();

  ObjectMetadata toMetadata() {
    return ObjectMetadata(
      inventoryNumber: _text(inventoryNumber),
      material: _text(material),
      period: _text(period),
      heightCm: _number(height),
      widthCm: _number(width),
      depthCm: _number(depth),
    );
  }

  void dispose() {
    for (final controller in [
      inventoryNumber,
      material,
      period,
      height,
      width,
      depth,
    ]) {
      controller.dispose();
    }
  }

  static String? _text(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  // A comma is the decimal mark on many of the keyboards this is typed on.
  static double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));
}

/// The fields that describe a museum object: what its label says, and its
/// size. All optional — the dashboard can complete them later.
class ObjectMetadataForm extends StatelessWidget {
  const ObjectMetadataForm({super.key, required this.controllers});

  final ObjectMetadataControllers controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelledField(
          label: 'Inventory number',
          hint: 'e.g. JE 30272',
          controller: controllers.inventoryNumber,
          capitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.lg),
        _LabelledField(
          label: 'Material',
          hint: 'e.g. Painted limestone',
          controller: controllers.material,
        ),
        const SizedBox(height: AppSpacing.lg),
        _LabelledField(
          label: 'Period / dynasty',
          hint: 'e.g. Dynasty 5',
          controller: controllers.period,
        ),
        const SizedBox(height: AppSpacing.lg),
        const FormFieldLabel('Size in cm'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _DimensionField(
                label: 'Height',
                controller: controllers.height,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DimensionField(
                label: 'Width',
                controller: controllers.width,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DimensionField(
                label: 'Depth',
                controller: controllers.depth,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.capitalization = TextCapitalization.sentences,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(label),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          textCapitalization: capitalization,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}
