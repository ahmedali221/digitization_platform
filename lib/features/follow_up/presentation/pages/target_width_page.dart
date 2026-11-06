import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/hardware/ar_measure_channel.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../domain/entities/target_width.dart';

/// Asks how wide a target is, by AR or typed from a tape. There is no way past
/// this without a width: every target needs one.
///
/// Shows the current target image because that's what must be measured. The
/// reviewer straightens a new photograph to the same framing, so the edges of
/// this picture are the edges of the final target, and any wall around them that
/// a new photograph caught isn't part of the width.
class TargetWidthPage extends StatefulWidget {
  const TargetWidthPage({
    super.key,
    required this.title,
    required this.imagePath,
    this.discardsPhotograph = false,
    this.currentMeters,
  });

  final String title;
  final String imagePath;

  /// Leaving here loses a photograph just taken, so it asks first.
  final bool discardsPhotograph;

  /// A width already known for this target. Someone who just measured it isn't
  /// made to do it again: they're asked first whether to use it.
  final double? currentMeters;

  @override
  State<TargetWidthPage> createState() => _TargetWidthPageState();
}

class _TargetWidthPageState extends State<TargetWidthPage> {
  final TextEditingController _typed = TextEditingController();

  bool _checkingAr = true;
  bool _arAvailable = false;
  bool _measuring = false;
  bool _typing = false;
  String? _arProblem;
  String? _typedError;
  late bool _askingAboutCurrent = widget.currentMeters != null;

  @override
  void initState() {
    super.initState();
    _checkAr();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _checkAr() async {
    final supported = await ArMeasureChannel.isSupported();
    if (!mounted) return;
    setState(() {
      _checkingAr = false;
      _arAvailable = supported;
      _typing = !supported;
      if (!supported) _arProblem = 'AR can’t be used on this phone, so type the width instead.';
    });
  }

  Future<void> _measure() async {
    setState(() => _measuring = true);
    final result = await ArMeasureChannel.measure();
    if (!mounted) return;
    setState(() => _measuring = false);

    switch (result.status) {
      case ArMeasureStatus.measured:
        final meters = result.meters!;
        if (TargetWidth.isValid(meters)) {
          Navigator.of(context).pop(TargetWidth(meters, TargetWidth.sourceAr));
        } else {
          setState(() => _arProblem = 'That measured ${TargetWidth.format(meters)}, which can’t be right. Measure again.');
        }
      case ArMeasureStatus.cancelled:
        break;
      case ArMeasureStatus.unavailable:
        setState(() {
          _arAvailable = false;
          _typing = true;
          _arProblem = '${result.reason ?? 'AR can’t be used right now.'} Type the width instead.';
        });
    }
  }

  void _useTyped() {
    final meters = TargetWidth.parseMeters(_typed.text);
    if (meters == null) {
      setState(() {
        _typedError =
            'Enter the width in metres, between ${TargetWidth.minMeters} and ${TargetWidth.maxMeters.toInt()}.';
      });
      return;
    }
    Navigator.of(context).pop(TargetWidth(meters, TargetWidth.sourceManual));
  }

  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave without a width?'),
        content: const Text('The photograph you just took won’t be sent. A target can’t be replaced without its width.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard photograph'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) navigator.pop();
  }

  /// The choice offered when a width is already known.
  List<Widget> _currentWidthChoice(double meters, TextTheme textTheme) {
    return [
      Text('Width already measured: ${TargetWidth.format(meters)}', style: textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      PrimaryActionButton(
        icon: Icons.check,
        label: 'Use ${TargetWidth.format(meters)}',
        onTap: () => Navigator.of(context).pop(TargetWidth(meters, TargetWidth.sourceExisting)),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton.icon(
        icon: const Icon(Icons.straighten),
        label: const Text('Measure again'),
        onPressed: () => setState(() => _askingAboutCurrent = false),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !widget.discardsPhotograph,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Measure this target’s width', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Measure what this picture shows, from its left edge to its right edge. '
                'Leave out any wall around it.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: Image.file(File(widget.imagePath), cacheWidth: 1000),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_askingAboutCurrent) ..._currentWidthChoice(widget.currentMeters!, textTheme)
              else ...[
              if (_arProblem != null) ...[
                Text(_arProblem!, style: textTheme.bodySmall?.copyWith(color: AppColors.onWarningContainer)),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_arAvailable)
                PrimaryActionButton(
                  icon: Icons.straighten,
                  label: _measuring ? 'Measuring…' : 'Measure with AR',
                  enabled: !_measuring && !_checkingAr,
                  onTap: _measure,
                ),
              if (_arAvailable && !_typing)
                TextButton(
                  onPressed: () => setState(() => _typing = true),
                  child: const Text('Type it instead'),
                ),
              if (_typing) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _typed,
                  autofocus: !_arAvailable,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Width in metres',
                    hintText: '1.42',
                    suffixText: 'm',
                    errorText: _typedError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_typedError != null) setState(() => _typedError = null);
                  },
                  onSubmitted: (_) => _useTyped(),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: _useTyped, child: const Text('Use this width')),
              ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
