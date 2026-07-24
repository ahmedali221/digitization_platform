import 'package:flutter/material.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import 'grid_capture_metrics.dart';

/// Keeps every grid cell within reach while the camera stays open.
///
/// The row-major strip mirrors the capture grid, shows each cell's photo
/// count, and scrolls the active cell into view when selection changes.
class CameraGridNavigator extends StatefulWidget {
  const CameraGridNavigator({
    super.key,
    required this.grid,
    required this.activeCellIndex,
    required this.onCellSelected,
    this.enabled = true,
  });

  final GridState grid;
  final int activeCellIndex;
  final ValueChanged<int> onCellSelected;
  final bool enabled;

  @override
  State<CameraGridNavigator> createState() => _CameraGridNavigatorState();
}

class _CameraGridNavigatorState extends State<CameraGridNavigator> {
  static const _cellWidth = 68.0;
  static const _cellGap = AppSpacing.sm;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _offsetFor(widget.activeCellIndex),
    );
  }

  @override
  void didUpdateWidget(covariant CameraGridNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeCellIndex != widget.activeCellIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActiveCell());
    }
  }

  double _offsetFor(int index) => index * (_cellWidth + _cellGap);

  void _revealActiveCell() {
    if (!mounted || !_scrollController.hasClients) return;
    final target = _offsetFor(
      widget.activeCellIndex,
    ).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cameraBackground,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    'Grid cells',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.grid.filledCount}/${widget.grid.cells.length} covered',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 64,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: widget.grid.cells.length,
                separatorBuilder: (_, _) => const SizedBox(width: _cellGap),
                itemBuilder: (context, index) {
                  final row = index ~/ widget.grid.cols + 1;
                  final col = index % widget.grid.cols + 1;
                  return SizedBox(
                    width: _cellWidth,
                    child: _CameraGridCell(
                      key: ValueKey('camera-grid-cell-$index'),
                      label: 'R${row}C$col',
                      photoCount: widget.grid.cells[index].photoCount,
                      isActive: index == widget.activeCellIndex,
                      onTap: widget.enabled
                          ? () => widget.onCellSelected(index)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraGridCell extends StatelessWidget {
  const _CameraGridCell({
    super.key,
    required this.label,
    required this.photoCount,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int photoCount;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhotos = photoCount > 0;
    final capturedColor = WallStatus.captured.meta.border;
    final background = isActive
        ? AppColors.seed
        : hasPhotos
        ? capturedColor.withValues(alpha: 0.35)
        : GridCaptureMetrics.cameraThumbBackground;
    final borderColor = isActive
        ? Colors.white
        : hasPhotos
        ? capturedColor
        : Colors.white24;

    return Semantics(
      button: true,
      selected: isActive,
      label:
          '$label, ${hasPhotos ? '$photoCount photos' : 'empty'}${isActive ? ', selected' : ''}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: isActive ? 2 : 1),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPhotos ? Icons.photo_camera : Icons.add_a_photo,
                      size: 15,
                      color: Colors.white70,
                    ),
                    if (hasPhotos) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$photoCount',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
