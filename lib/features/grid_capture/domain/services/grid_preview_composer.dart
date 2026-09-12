import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../entities/capture_quality.dart';

/// One scored shared edge, for the colored border line drawn along it
/// (spec §5: "a thin coloured line along each shared edge scored by its
/// own neighbour_score — so a user can immediately see which side of a
/// cell is the weak one").
class EdgeTierEntry {
  const EdgeTierEntry({
    required this.cellIndex,
    required this.direction,
    required this.tier,
  });

  final int cellIndex;
  final NeighbourDirection direction;
  final QualityTier tier;
}

/// Request payload for [composeGridPreview]. Must be plain data — it
/// crosses an isolate boundary via `compute()`, so it can't carry the
/// [GridState]/[GridCell] domain objects themselves.
class GridPreviewRequest {
  const GridPreviewRequest({
    required this.rows,
    required this.cols,
    required this.cellShotPaths,
    this.cellTiers = const {},
    this.edgeTiers = const [],
  });

  final int rows;
  final int cols;

  /// One path per cell, row-major (matches `GridState.cells`); null for a
  /// cell with no photo yet.
  final List<String?> cellShotPaths;

  /// Tier 1-3 heat color per cell index (spec §5's Tier 4 overlay) — absent
  /// entries are unscored and get no tint.
  final Map<int, QualityTier> cellTiers;

  /// One entry per scored shared edge.
  final List<EdgeTierEntry> edgeTiers;
}

const _cellSize = 360;
// Matches the "~20-30% overlap into neighboring cells" guidance already
// shown on the capture screen — trimming this fraction removes the
// duplicated content instead of aligning it by pixel content.
const _overlapFraction = 0.25;

const _cellTintAlpha = 90; // out of 255 — visible but keeps the photo legible
const _edgeLineThickness = 5.0;

/// Composes an approximate, position-based grid preview — NOT a real
/// panorama. Each cell's first shot is placed at its known (row, col) slot
/// and trimmed by the known overlap fraction on edges shared with another
/// filled cell; there is no feature-matching/keypoint alignment, which
/// FLUTTER_MOBILE_PLAN.md rules out as unreliable for these photo
/// conditions. This output is advisory only — the caller must never persist
/// or sync it; the real panorama is still composed by a human on the
/// dashboard.
///
/// Must stay a top-level function: `compute()` runs it in a fresh isolate
/// that only receives [request], not any surrounding instance state.
Uint8List composeGridPreview(GridPreviewRequest request) {
  final canvas = img.Image(
    width: request.cols * _cellSize,
    height: request.rows * _cellSize,
  );
  img.fill(canvas, color: img.ColorRgb8(60, 60, 60));

  for (var row = 0; row < request.rows; row++) {
    for (var col = 0; col < request.cols; col++) {
      final index = row * request.cols + col;
      final tile =
          _loadTile(request.cellShotPaths[index]) ?? _placeholderTile();
      final trimmed = _trimOverlap(
        tile,
        trimLeft: col > 0,
        trimTop: row > 0,
        trimRight: col < request.cols - 1,
        trimBottom: row < request.rows - 1,
      );
      img.compositeImage(
        canvas,
        trimmed,
        dstX: col * _cellSize,
        dstY: row * _cellSize,
      );
    }
  }

  _paintQualityOverlay(canvas, request);

  return img.encodeJpg(canvas, quality: 85);
}

/// Tier 4's heat overlay (spec §5): a translucent tint over every scored
/// cell's footprint, then a colored line along every scored shared edge —
/// drawn once over the fully-assembled canvas so lines land exactly on the
/// seams between tiles regardless of trimming.
void _paintQualityOverlay(img.Image canvas, GridPreviewRequest request) {
  for (final entry in request.cellTiers.entries) {
    final row = entry.key ~/ request.cols;
    final col = entry.key % request.cols;
    final color = _tintColor(entry.value);
    img.fillRect(
      canvas,
      x1: col * _cellSize,
      y1: row * _cellSize,
      x2: (col + 1) * _cellSize - 1,
      y2: (row + 1) * _cellSize - 1,
      color: color,
    );
  }

  for (final edge in request.edgeTiers) {
    final row = edge.cellIndex ~/ request.cols;
    final col = edge.cellIndex % request.cols;
    final color = _lineColor(edge.tier);
    final x0 = col * _cellSize;
    final y0 = row * _cellSize;
    final x1 = (col + 1) * _cellSize - 1;
    final y1 = (row + 1) * _cellSize - 1;
    switch (edge.direction) {
      case NeighbourDirection.left:
        img.drawLine(canvas, x1: x0, y1: y0, x2: x0, y2: y1, color: color, thickness: _edgeLineThickness);
      case NeighbourDirection.right:
        img.drawLine(canvas, x1: x1, y1: y0, x2: x1, y2: y1, color: color, thickness: _edgeLineThickness);
      case NeighbourDirection.top:
        img.drawLine(canvas, x1: x0, y1: y0, x2: x1, y2: y0, color: color, thickness: _edgeLineThickness);
      case NeighbourDirection.bottom:
        img.drawLine(canvas, x1: x0, y1: y1, x2: x1, y2: y1, color: color, thickness: _edgeLineThickness);
    }
  }
}

img.ColorRgba8 _tintColor(QualityTier tier) {
  final (r, g, b) = _rgbFor(tier);
  return img.ColorRgba8(r, g, b, _cellTintAlpha);
}

img.ColorRgba8 _lineColor(QualityTier tier) {
  final (r, g, b) = _rgbFor(tier);
  return img.ColorRgba8(r, g, b, 255);
}

/// Spec §5's exact hex values, written out again here rather than pulled
/// from `QualityTierMeta` (grid_capture's presentation layer): that file
/// carries a `dart:ui` `Color`, and this compositor must stay callable
/// without the Flutter engine (see `analyzeCellQuality`'s doc comment for
/// why CaptureAnalyzer types are kept Flutter-free — this file inherits the
/// same constraint since it consumes their output). Keep in sync with
/// `quality_tier_meta.dart` if the palette ever changes.
(int, int, int) _rgbFor(QualityTier tier) => switch (tier) {
  QualityTier.red => (0xE5, 0x39, 0x35),
  QualityTier.orange => (0xFB, 0x8C, 0x00),
  QualityTier.yellow => (0xFD, 0xD8, 0x35),
  QualityTier.green => (0x43, 0xA0, 0x47),
};

img.Image? _loadTile(String? path) {
  if (path == null) return null;
  try {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.copyResizeCropSquare(decoded, size: _cellSize);
  } catch (_) {
    // Missing/corrupt file — fall back to a placeholder rather than
    // failing the whole preview over one bad shot.
    return null;
  }
}

img.Image _placeholderTile() {
  final tile = img.Image(width: _cellSize, height: _cellSize);
  img.fill(tile, color: img.ColorRgb8(120, 120, 120));
  return tile;
}

/// Crops the overlap fraction off edges bordering another filled cell, then
/// resizes back up to [_cellSize] so every cell still tiles evenly — the
/// trim discards duplicated content, not the slot's footprint on the grid.
img.Image _trimOverlap(
  img.Image tile, {
  required bool trimLeft,
  required bool trimTop,
  required bool trimRight,
  required bool trimBottom,
}) {
  final overlapPx = (_cellSize * _overlapFraction / 2).round();
  final x = trimLeft ? overlapPx : 0;
  final y = trimTop ? overlapPx : 0;
  final width = _cellSize - x - (trimRight ? overlapPx : 0);
  final height = _cellSize - y - (trimBottom ? overlapPx : 0);
  final cropped = img.copyCrop(tile, x: x, y: y, width: width, height: height);
  return img.copyResize(cropped, width: _cellSize, height: _cellSize);
}
