import 'package:flutter/material.dart';

import 'grid_capture_metrics.dart';

/// Renders the wall's capture-cell grid. Grids can now go up to 20×20 (see
/// `CaptureSessionCubit`'s `_maxGridDimension`) — letting
/// [SliverGridDelegateWithFixedCrossAxisCount] auto-fit that many columns
/// into the screen width would shrink cells past the point of being tappable
/// or legible, so once the natural cell size would drop below
/// [_minCellExtent] this switches to a fixed cell size and lets the grid
/// scroll horizontally instead.
class ScrollableCellGrid extends StatelessWidget {
  const ScrollableCellGrid({
    super.key,
    required this.cols,
    required this.cellCount,
    required this.itemBuilder,
    this.bottomPadding = 0,
  });

  final int cols;
  final int cellCount;
  final IndexedWidgetBuilder itemBuilder;
  final double bottomPadding;

  static const double _minCellExtent = 84;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - GridCaptureMetrics.horizontalPadding * 2;
        final fittedExtent =
            (availableWidth - GridCaptureMetrics.gap * (cols - 1)) / cols;
        final needsHorizontalScroll = fittedExtent < _minCellExtent;
        final cellExtent = needsHorizontalScroll
            ? _minCellExtent
            : fittedExtent;
        final gridWidth =
            cellExtent * cols + GridCaptureMetrics.gap * (cols - 1);

        final grid = GridView.builder(
          padding: EdgeInsets.fromLTRB(
            GridCaptureMetrics.horizontalPadding,
            0,
            GridCaptureMetrics.horizontalPadding,
            bottomPadding,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: GridCaptureMetrics.gap,
            crossAxisSpacing: GridCaptureMetrics.gap,
            childAspectRatio: 1,
          ),
          itemCount: cellCount,
          itemBuilder: itemBuilder,
        );

        if (!needsHorizontalScroll) return grid;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth + GridCaptureMetrics.horizontalPadding * 2,
            child: grid,
          ),
        );
      },
    );
  }
}
