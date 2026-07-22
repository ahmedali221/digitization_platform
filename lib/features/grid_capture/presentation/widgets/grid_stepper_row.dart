import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A labeled +/- stepper row used for the custom rows/columns pickers on the
/// grid-init screen.
class GridStepperRow extends StatelessWidget {
  const GridStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryIcon),
        ),
        Row(
          children: [
            _StepperButton(icon: Icons.remove, onTap: onDecrement),
            SizedBox(
              width: 16,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _StepperButton(icon: Icons.add, onTap: onIncrement),
          ],
        ),
      ],
    );
  }
}

/// A persistent-background circular button (unlike [CircleIconButton], which
/// is transparent until hovered/pressed) — the stepper +/- affordance always
/// shows its gray chip. Tap area is padded out to 48x48dp per
/// DESIGN_SYSTEM.md §9 even though the visual chip is 32dp.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.hoverSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondaryIcon),
            ),
          ),
        ),
      ),
    );
  }
}
