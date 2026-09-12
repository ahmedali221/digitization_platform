import 'package:flutter/material.dart';

import '../../domain/entities/capture_quality.dart';

class QualityTierMeta {
  const QualityTierMeta({
    required this.color,
    required this.label,
    required this.meaning,
  });

  final Color color;
  final String label;
  final String meaning;
}

/// Single source of truth for quality-tier colors — spec §5's exact hex
/// values, never inlined in feature code (CLAUDE.md's SOLID/DIP rule).
/// Lives in grid_capture's own presentation layer, not `core/theme/`
/// alongside `WallStatus`: unlike wall status, nothing outside this feature
/// reads a [QualityTier]'s color.
const Map<QualityTier, QualityTierMeta> kQualityTierMeta = {
  QualityTier.red: QualityTierMeta(
    color: Color(0xFFE53935),
    label: 'Red',
    meaning: 'Bad — retake',
  ),
  QualityTier.orange: QualityTierMeta(
    color: Color(0xFFFB8C00),
    label: 'Orange',
    meaning: 'Weak — usable as a last resort',
  ),
  QualityTier.yellow: QualityTierMeta(
    color: Color(0xFFFDD835),
    label: 'Yellow',
    meaning: 'Acceptable — will probably work',
  ),
  QualityTier.green: QualityTierMeta(
    color: Color(0xFF43A047),
    label: 'Green',
    meaning: 'Good — move on',
  ),
};

extension QualityTierX on QualityTier {
  QualityTierMeta get meta => kQualityTierMeta[this]!;
}
