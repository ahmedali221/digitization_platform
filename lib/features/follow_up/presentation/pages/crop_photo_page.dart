import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback_states.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// The part of a photograph to keep, as fractions of it as displayed.
class CropBox {
  const CropBox(this.left, this.top, this.right, this.bottom);

  /// Below this a corner handle would sit on another, and there's no text left.
  static const double minimumSize = 0.08;

  final double left;
  final double top;
  final double right;
  final double bottom;

  CropBox withCorner(int corner, double x, double y) {
    final clampedX = x.clamp(0.0, 1.0);
    final clampedY = y.clamp(0.0, 1.0);
    final isLeft = corner == 0 || corner == 3;
    final isTop = corner == 0 || corner == 1;
    return CropBox(
      isLeft ? clampedX.clamp(0.0, right - minimumSize) : left,
      isTop ? clampedY.clamp(0.0, bottom - minimumSize) : top,
      isLeft ? right : clampedX.clamp(left + minimumSize, 1.0),
      isTop ? bottom : clampedY.clamp(top + minimumSize, 1.0),
    );
  }
}

/// Crops a photograph to just the text. A whole-scene photo gives the index
/// little to read, which is what most of the remaining failures come down to.
/// Pops with the [CropBox].
class CropPhotoPage extends StatefulWidget {
  const CropPhotoPage({super.key, required this.photoPath});

  final String photoPath;

  @override
  State<CropPhotoPage> createState() => _CropPhotoPageState();
}

class _CropPhotoPageState extends State<CropPhotoPage> {
  CropBox _box = const CropBox(0.05, 0.05, 0.95, 0.95);
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  /// The image's size as displayed, so the box lands where it's seen. Decoding
  /// through the engine applies the EXIF orientation, as the crop itself will.
  Future<void> _readSize() async {
    final bytes = await File(widget.photoPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
    final frame = await codec.getNextFrame();
    final ratio = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (mounted) setState(() => _aspectRatio = ratio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop to the text')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _aspectRatio == null
                  ? const LoadingIndicator()
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AspectRatio(
                          aspectRatio: _aspectRatio!,
                          child: LayoutBuilder(
                            builder: (context, constraints) => _CropArea(
                              path: widget.photoPath,
                              box: _box,
                              size: constraints.biggest,
                              onChanged: (box) => setState(() => _box = box),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Drag the corners close around the text.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryActionButton(
                    label: 'Use this crop',
                    onTap: () => Navigator.of(context).pop(_box),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropArea extends StatelessWidget {
  const _CropArea({required this.path, required this.box, required this.size, required this.onChanged});

  static const double _handleSize = 44;
  static const int _previewWidth = 1400;

  final String path;
  final CropBox box;
  final Size size;
  final ValueChanged<CropBox> onChanged;

  @override
  Widget build(BuildContext context) {
    final corners = [
      Offset(box.left, box.top),
      Offset(box.right, box.top),
      Offset(box.right, box.bottom),
      Offset(box.left, box.bottom),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.file(File(path), fit: BoxFit.fill, cacheWidth: _previewWidth),
        ),
        Positioned.fill(child: CustomPaint(painter: _ShadePainter(box))),
        for (var i = 0; i < corners.length; i++)
          Positioned(
            left: corners[i].dx * size.width - _handleSize / 2,
            top: corners[i].dy * size.height - _handleSize / 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final current = [
                  Offset(box.left, box.top),
                  Offset(box.right, box.top),
                  Offset(box.right, box.bottom),
                  Offset(box.left, box.bottom),
                ][i];
                onChanged(
                  box.withCorner(
                    i,
                    current.dx + details.delta.dx / size.width,
                    current.dy + details.delta.dy / size.height,
                  ),
                );
              },
              child: const SizedBox(
                width: _handleSize,
                height: _handleSize,
                child: Center(child: _CropHandle()),
              ),
            ),
          ),
      ],
    );
  }
}

class _CropHandle extends StatelessWidget {
  const _CropHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: AppColors.seed,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
  );
}

class _ShadePainter extends CustomPainter {
  const _ShadePainter(this.box);

  final CropBox box;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas
      ..drawPath(shade, Paint()..color = AppColors.cameraScrim)
      ..drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_ShadePainter oldDelegate) => oldDelegate.box != box;
}
