import 'package:flutter/material.dart';

/// Wall/aggregate status values, shared contract with the web dashboard
/// (`resources/js/stores/canvasHelpers.js:statusColor`). See DESIGN_SYSTEM.md §2.2.
enum WallStatus { notStarted, inProgress, captured, done, skipped }

class WallStatusMeta {
  const WallStatusMeta({
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color background;
  final Color border;
  final IconData icon;
  final String label;
}

/// Single source of truth for wall-status colors/icons — never inline hex in
/// feature code (CLAUDE.md's SOLID/DIP rule).
const Map<WallStatus, WallStatusMeta> kWallStatusMeta = {
  WallStatus.notStarted: WallStatusMeta(
    color: Color(0xFF6B7280),
    background: Color(0xFFF1F2F4),
    border: Color(0xFFD1D5DB),
    icon: Icons.radio_button_unchecked,
    label: 'Not started',
  ),
  WallStatus.inProgress: WallStatusMeta(
    color: Color(0xFFD97706),
    background: Color(0xFFFEF3C7),
    border: Color(0xFFFCD34D),
    icon: Icons.autorenew,
    label: 'In progress',
  ),
  WallStatus.captured: WallStatusMeta(
    color: Color(0xFF2563EB),
    background: Color(0xFFDBEAFE),
    border: Color(0xFF93C5FD),
    icon: Icons.cloud_done,
    label: 'Captured',
  ),
  WallStatus.done: WallStatusMeta(
    color: Color(0xFF059669),
    background: Color(0xFFD1FAE5),
    border: Color(0xFF6EE7B7),
    icon: Icons.check_circle,
    label: 'Done',
  ),
  WallStatus.skipped: WallStatusMeta(
    color: Color(0xFF64748B),
    background: Color(0xFFE2E8F0),
    border: Color(0xFFCBD5E1),
    icon: Icons.block,
    label: 'Skipped',
  ),
};

extension WallStatusX on WallStatus {
  WallStatusMeta get meta => kWallStatusMeta[this]!;
}

/// Priority order matching the FLUTTER_MOBILE_PLAN.md §4 status machine:
/// aggregate is `done` only if every wall is done, `skipped` only if every
/// wall is skipped, `captured` if every wall is done/captured, `in_progress`
/// if any wall has started, else `not_started`.
WallStatus aggregateWallStatus(List<WallStatus> walls) {
  if (walls.isEmpty) return WallStatus.notStarted;
  if (walls.every((s) => s == WallStatus.done)) return WallStatus.done;
  if (walls.every((s) => s == WallStatus.skipped)) return WallStatus.skipped;
  if (walls.every((s) => s == WallStatus.done || s == WallStatus.captured)) {
    return WallStatus.captured;
  }
  if (walls.any(
    (s) =>
        s == WallStatus.inProgress ||
        s == WallStatus.captured ||
        s == WallStatus.done,
  )) {
    return WallStatus.inProgress;
  }
  return WallStatus.notStarted;
}
