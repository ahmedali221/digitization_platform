import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/object_type_meta.dart';

/// One of an object's six sides on the organised capture screen: its
/// photograph once it has one, an invitation to take it until then.
class SideTile extends StatelessWidget {
  const SideTile({
    super.key,
    required this.side,
    required this.photoPath,
    required this.onTap,
  });

  /// The widest a tile's picture is ever drawn, in logical pixels — what the
  /// decoder is asked for instead of the full tens-of-megapixels shot.
  static const double _decodeExtent = 320;
  static const double _emptyIconSize = 32;

  final ObjectSide side;
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoPath = this.photoPath;
    final isCaptured = photoPath != null;

    return Semantics(
      button: true,
      label: isCaptured
          ? '${side.label} side, photographed. Open photograph.'
          : '${side.label} side, not photographed. Take photograph.',
      child: Material(
        color: AppColors.surfaceNeutral,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(
                color: isCaptured ? AppColors.seed : AppColors.outlineSubtle,
                width: isCaptured ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isCaptured)
                  Image.file(
                    File(photoPath),
                    fit: BoxFit.cover,
                    cacheWidth:
                        (_decodeExtent * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: AppColors.iconMuted,
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: _emptyIconSize,
                      color: AppColors.iconMuted,
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _SideLabel(side: side, isCaptured: isCaptured),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.side, required this.isCaptured});

  final ObjectSide side;
  final bool isCaptured;

  @override
  Widget build(BuildContext context) {
    final color = isCaptured ? Colors.white : AppColors.textSecondaryIcon;
    return Container(
      width: double.infinity,
      color: isCaptured ? AppColors.cameraScrim : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCaptured) ...[
            Icon(Icons.check_circle, size: AppSpacing.lg, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              side.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
