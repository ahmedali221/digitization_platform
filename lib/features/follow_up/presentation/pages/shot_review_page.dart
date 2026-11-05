import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/services/shot_processing.dart';

/// Suggests the sharpest shot and lets the operator choose: sharpness can't tell
/// a sharp photo of the wrong thing from the right one. Pops with the chosen path.
class ShotReviewPage extends StatefulWidget {
  const ShotReviewPage({super.key, required this.shots});

  final List<String> shots;

  @override
  State<ShotReviewPage> createState() => _ShotReviewPageState();
}

class _ShotReviewPageState extends State<ShotReviewPage> {
  String? _selected;
  String? _sharpest;
  bool _measuring = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.shots.first;
    _measure();
  }

  Future<void> _measure() async {
    if (widget.shots.length == 1) {
      setState(() => _measuring = false);
      return;
    }
    try {
      final scores = await compute(measureSharpness, widget.shots);
      if (!mounted) return;
      final sharpest = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      setState(() {
        _sharpest = sharpest;
        _selected = sharpest;
      });
    } catch (_) {
      // The suggestion is a convenience: the operator can still choose by eye.
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose the best shot')),
      body: SafeArea(
        child: Column(
          children: [
            if (_measuring)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: LoadingIndicator(inline: true),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: widget.shots.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final path = widget.shots[index];
                  return _ShotOption(
                    path: path,
                    selected: path == _selected,
                    suggested: path == _sharpest,
                    onTap: () => setState(() => _selected = path),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryActionButton(
                label: 'Use this shot',
                onTap: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotOption extends StatelessWidget {
  const _ShotOption({
    required this.path,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  static const int _previewWidth = 1000;

  final String path;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.seed : AppColors.outlineSubtle,
            width: selected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.file(File(path), cacheWidth: _previewWidth, width: double.infinity),
            if (suggested)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    'Sharpest',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSuccessContainer),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
