import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Full-screen, ephemeral panorama preview. Never persisted, synced, or
/// deep-linked — reached only via `Navigator.push` from the coverage-review
/// screen, and its bytes are discarded the moment this screen is popped.
class GridPreviewScreen extends StatelessWidget {
  const GridPreviewScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(child: Image.memory(imageBytes)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Approximate preview — the final panorama is composed on '
                'the dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
