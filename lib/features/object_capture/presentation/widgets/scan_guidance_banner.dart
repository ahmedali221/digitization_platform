import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/services/auto_shutter.dart';

/// The one thing the operator should do right now, in a few words over the
/// viewfinder.
class ScanGuidanceBanner extends StatelessWidget {
  const ScanGuidanceBanner({
    super.key,
    required this.guidance,
    required this.ring,
  });

  final ScanGuidance guidance;

  /// The ring being shot, whose instruction is shown when the phone is at
  /// the wrong height for it.
  final ScanRing ring;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (guidance) {
      ScanGuidance.shoot => (Icons.camera, 'Hold still'),
      ScanGuidance.holdStill => (Icons.pan_tool_outlined, 'Hold still'),
      ScanGuidance.slowDown => (Icons.speed, 'Slower'),
      ScanGuidance.moveRight => (Icons.arrow_forward, 'Step to the right'),
      ScanGuidance.moveLeft => (Icons.arrow_back, 'Step to the left'),
      ScanGuidance.wrongHeight => (Icons.height, ring.instruction),
      ScanGuidance.finished => (Icons.check_circle, 'Every side is covered'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cameraScrim,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
