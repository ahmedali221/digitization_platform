import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Request payload for [composeGridPreview]. Must be plain data — it
/// crosses an isolate boundary via `compute()`, so it can't carry the
/// [GridState]/[GridCell] domain objects themselves.
class GridPreviewRequest {
  const GridPreviewRequest({
    required this.rows,
    required this.cols,
    required this.cellShotPaths,
  });

  final int rows;
  final int cols;

  /// One path per cell, row-major (matches `GridState.cells`); null for a
  /// cell with no photo yet.
  final List<String?> cellShotPaths;
}

const _cellSize = 360;
// Matches the "~20-30% overlap into neighboring cells" guidance already
// shown on the capture screen — trimming this fraction removes the
// duplicated content instead of aligning it by pixel content.
const _overlapFraction = 0.25;

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

  return img.encodeJpg(canvas, quality: 85);
}

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
