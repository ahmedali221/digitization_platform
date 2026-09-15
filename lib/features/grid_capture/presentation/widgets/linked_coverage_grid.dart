import 'package:flutter/material.dart';

import '../../domain/entities/capture_quality.dart';
import 'cell_link_indicator.dart';
import 'grid_capture_metrics.dart';

/// Looks up the [NeighbourMatchMetrics] linking [fromIndex] to [toIndex]
/// (either direction — a cell's own neighbour list may not have an entry for
/// a pair the other side already scored), or null if that pair hasn't been
/// scored yet.
typedef LinkMetricsLookup =
    NeighbourMatchMetrics? Function(int fromIndex, int toIndex);

/// The coverage-review grid, cell tiles plus the [CellLinkIndicator]
/// connectors between every grid-adjacent pair — "how those will be linked
/// together" made visible, rather than the plain [ScrollableCellGrid] the
/// capture screens use, which has no room between cells for that.
///
/// Built as a plain `Column`/`Row` tree rather than a `GridView` (coverage
/// review's grid is capped at 400 cells — see `_maxGridCells` — so skipping
/// virtualization here costs nothing) since a lazy `GridView` can't host
/// content interleaved *between* its cells the way connectors need.
class LinkedCoverageGrid extends StatelessWidget {
  const LinkedCoverageGrid({
    super.key,
    required this.rows,
    required this.cols,
    required this.itemBuilder,
    required this.linkMetrics,
    this.bottomPadding = 0,
  });

  final int rows;
  final int cols;
  final IndexedWidgetBuilder itemBuilder;
  final LinkMetricsLookup linkMetrics;
  final double bottomPadding;

  static const double _minCellExtent = 84;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final linksWidth = kCellLinkStripSize * (cols - 1);
        final availableWidth =
            constraints.maxWidth -
            GridCaptureMetrics.horizontalPadding * 2 -
            linksWidth;
        final fittedExtent = availableWidth / cols;
        final needsHorizontalScroll = fittedExtent < _minCellExtent;
        final cellExtent = needsHorizontalScroll
            ? _minCellExtent
            : fittedExtent;
        final gridWidth = cellExtent * cols + linksWidth;

        final content = Padding(
          padding: EdgeInsets.fromLTRB(
            GridCaptureMetrics.horizontalPadding,
            0,
            GridCaptureMetrics.horizontalPadding,
            bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) _verticalLinkRow(row, cellExtent),
                _cellRow(context, row, cellExtent),
              ],
            ],
          ),
        );

        Widget scrollable = SingleChildScrollView(child: content);
        if (needsHorizontalScroll) {
          scrollable = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: gridWidth + GridCaptureMetrics.horizontalPadding * 2,
              child: scrollable,
            ),
          );
        }
        return scrollable;
      },
    );
  }

  Widget _cellRow(BuildContext context, int row, double cellExtent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var col = 0; col < cols; col++) ...[
          if (col > 0) _horizontalLink(row, col, cellExtent),
          SizedBox(
            width: cellExtent,
            height: cellExtent,
            child: itemBuilder(context, row * cols + col),
          ),
        ],
      ],
    );
  }

  Widget _verticalLinkRow(int row, double cellExtent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var col = 0; col < cols; col++) ...[
          if (col > 0) const SizedBox(width: kCellLinkStripSize),
          _verticalLink(row, col, cellExtent),
        ],
      ],
    );
  }

  Widget _horizontalLink(int row, int col, double cellExtent) {
    final leftIndex = row * cols + (col - 1);
    final rightIndex = row * cols + col;
    return SizedBox(
      height: cellExtent,
      child: CellLinkIndicator(
        axis: LinkAxis.horizontal,
        metrics: linkMetrics(leftIndex, rightIndex),
      ),
    );
  }

  Widget _verticalLink(int row, int col, double cellExtent) {
    final topIndex = (row - 1) * cols + col;
    final bottomIndex = row * cols + col;
    return SizedBox(
      width: cellExtent,
      child: CellLinkIndicator(
        axis: LinkAxis.vertical,
        metrics: linkMetrics(topIndex, bottomIndex),
      ),
    );
  }
}
