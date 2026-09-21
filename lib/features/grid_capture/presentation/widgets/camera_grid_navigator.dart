import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/domain/entities/wall.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/wall_status.dart';
import '../../domain/entities/capture_quality.dart';
import 'grid_capture_metrics.dart';
import 'quality_badge.dart';

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
    this.cellQuality = const {},
    this.enabled = true,
  });

  final GridState grid;
  final int activeCellIndex;
  final ValueChanged<int> onCellSelected;

  /// Capture Quality Indicator result per cell index — see
  /// [GridCaptureRepository.getCellQuality].
  final Map<int, CellQualityResult> cellQuality;
  final bool enabled;

  @override
  State<CameraGridNavigator> createState() => _CameraGridNavigatorState();
}

class _CameraGridNavigatorState extends State<CameraGridNavigator> {
  static const _cellWidth = 68.0;
  static const _cellGap = AppSpacing.sm;
  static const _rowDividerWidth = 40.0;

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

  bool _isRowBoundary(int separatorIndex) =>
      (separatorIndex + 1) % widget.grid.cols == 0;

  // The strip is row-major, so a row divider (wider than the ordinary cell
  // gap) sits at every separator that closes out a row — offsets have to
  // account for that extra width or `_revealActiveCell` under/overshoots.
  double _offsetFor(int index) {
    final rowDividers = index ~/ widget.grid.cols;
    final normalGaps = index - rowDividers;
    return index * _cellWidth +
        normalGaps * _cellGap +
        rowDividers * _rowDividerWidth;
  }

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
                separatorBuilder: (_, index) => _isRowBoundary(index)
                    ? _RowDivider(nextRow: (index + 1) ~/ widget.grid.cols + 1)
                    : const SizedBox(width: _cellGap),
                itemBuilder: (context, index) {
                  final row = index ~/ widget.grid.cols + 1;
                  final col = index % widget.grid.cols + 1;
                  final shotPaths = widget.grid.cells[index].shotPaths;
                  final quality = widget.cellQuality[index];
                  return SizedBox(
                    width: _cellWidth,
                    child: _CameraGridCell(
                      key: ValueKey('camera-grid-cell-$index'),
                      label: 'R${row}C$col',
                      photoCount: widget.grid.cells[index].photoCount,
                      thumbnailPath: representativeShotPath(shotPaths, quality),
                      isActive: index == widget.activeCellIndex,
                      qualityTier: quality?.tier,
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

/// Marks the boundary between one grid row and the next in the strip, since
/// the cells otherwise scroll past as one undifferentiated row-major line.
/// The badge names the row that starts right after it.
class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.nextRow});

  final int nextRow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _CameraGridNavigatorState._rowDividerWidth,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 2.5,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white70,
                  Colors.white70,
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.15, 0.85, 1],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.seed,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              'R$nextRow',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraGridCell extends StatelessWidget {
  const _CameraGridCell({
    super.key,
    required this.label,
    required this.photoCount,
    this.thumbnailPath,
    required this.isActive,
    this.qualityTier,
    required this.onTap,
  });

  final String label;
  final int photoCount;
  final String? thumbnailPath;
  final bool isActive;
  final QualityTier? qualityTier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = this.thumbnailPath;
    final hasPhotos = photoCount > 0;
    final capturedColor = WallStatus.captured.meta.border;
    final background = thumbnailPath != null
        ? Colors.black
        : isActive
        ? AppColors.seed
        : hasPhotos
        ? capturedColor.withValues(alpha: 0.35)
        : GridCaptureMetrics.cameraThumbBackground;
    final borderColor = isActive
        ? Colors.orange.shade300
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: isActive ? 2 : 1),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailPath != null)
                  Image.file(
                    File(thumbnailPath),
                    fit: BoxFit.cover,
                    // Same reasoning as GridCellTile: decode at the strip's
                    // actual _cellWidth instead of the full capture
                    // resolution, since BoxFit.cover would discard the rest
                    // anyway.
                    cacheWidth: (_CameraGridNavigatorState._cellWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                if (thumbnailPath != null)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x8A000000)],
                      ),
                    ),
                  ),
                Column(
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (qualityTier != null)
                  Positioned(top: 4, right: 4, child: QualityDot(tier: qualityTier!, size: 9)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
