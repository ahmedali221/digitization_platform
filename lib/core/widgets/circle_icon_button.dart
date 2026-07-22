import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular icon button with the prototype's hover/press background —
/// used for back/close/sync/unassigned actions in headers and sheets.
/// [visualDiameter] matches the design (36 or 40dp); the tappable area is
/// always padded out to at least 48x48dp (DESIGN_SYSTEM.md §9).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.visualDiameter = 36,
    this.iconSize = 20,
    this.color = AppColors.textSecondaryIcon,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double visualDiameter;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tapDiameter = visualDiameter < 48 ? 48.0 : visualDiameter;
    return SizedBox(
      width: tapDiameter,
      height: tapDiameter,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          hoverColor: AppColors.hoverSurface,
          splashColor: AppColors.hoverSurface,
          child: Center(
            child: SizedBox(
              width: visualDiameter,
              height: visualDiameter,
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
