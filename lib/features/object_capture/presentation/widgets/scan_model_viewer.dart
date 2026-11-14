import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A 3D model the operator turns with a finger. Shown on a dark ground, so
/// a hole in the model reads as a hole and not as a pale patch of it.
class ScanModelViewer extends StatelessWidget {
  const ScanModelViewer({super.key, required this.modelPath});

  /// A `.glb` file on this phone.
  final String modelPath;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: ModelViewer(
          // A new model is a new page for the viewer: it does not reload one
          // it already shows.
          key: ValueKey(modelPath),
          src: Uri.file(modelPath).toString(),
          alt: 'Rough 3D model of the scanned object',
          backgroundColor: AppColors.cameraBackground,
          interactionPrompt: InteractionPrompt.none,
          ar: false,
          debugLogging: false,
        ),
      ),
    );
  }
}
