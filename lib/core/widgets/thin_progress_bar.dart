import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 6px rounded progress bar used for site downloads and sync uploads.
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.seed,
    this.trackColor = AppColors.outlineSubtle,
  });

  /// 0.0 - 1.0
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
