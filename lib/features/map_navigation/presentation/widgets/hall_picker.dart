import 'package:flutter/material.dart';

import '../../../../core/domain/entities/hall.dart';
import '../../../../core/theme/app_spacing.dart';

/// Chooses the hall a new item is filed under: one of the floor's own, or a
/// new one named here. Picking from the list instead of typing the name is
/// what stops "Hall 3" and "hall3" becoming two halls.
class HallPicker extends StatefulWidget {
  const HallPicker({
    super.key,
    required this.halls,
    required this.selected,
    required this.onSelected,
    required this.hallWord,
  });

  final List<HallEntity> halls;
  final HallEntity? selected;

  /// Null means "none": the item goes to the floor's unsorted hall.
  final ValueChanged<HallEntity?> onSelected;

  /// What this site calls a hall, lower case: "room" or "hall".
  final String hallWord;

  @override
  State<HallPicker> createState() => _HallPickerState();
}

class _HallPickerState extends State<HallPicker> {
  final _newHallName = TextEditingController();
  bool _isNamingNew = false;

  @override
  void dispose() {
    _newHallName.dispose();
    super.dispose();
  }

  void _startNamingNew() {
    setState(() => _isNamingNew = true);
    _reportNewName(_newHallName.text);
  }

  void _pick(HallEntity? hall) {
    setState(() => _isNamingNew = false);
    widget.onSelected(hall);
  }

  void _reportNewName(String text) {
    final name = text.trim();
    widget.onSelected(name.isEmpty ? null : _existingOrNew(name));
  }

  /// A typed name that matches one of the floor's halls is that hall.
  HallEntity _existingOrNew(String name) {
    for (final hall in widget.halls) {
      if (hall.name.toLowerCase() == name.toLowerCase()) return hall;
    }
    return HallEntity(name: name);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('None'),
              selected: !_isNamingNew && selected == null,
              onSelected: (_) => _pick(null),
            ),
            for (final hall in widget.halls)
              ChoiceChip(
                label: Text(hall.name),
                selected: !_isNamingNew && selected == hall,
                onSelected: (_) => _pick(hall),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.add, size: AppSpacing.lg),
              label: Text('New ${widget.hallWord}'),
              // The tick would be drawn over the plus sign.
              showCheckmark: false,
              selected: _isNamingNew,
              onSelected: (_) => _startNamingNew(),
            ),
          ],
        ),
        if (_isNamingNew) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _newHallName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: _reportNewName,
            decoration: InputDecoration(
              hintText: 'Name of the new ${widget.hallWord}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
