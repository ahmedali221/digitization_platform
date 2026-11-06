import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Both functions here run inside a `compute()` isolate: decoding full-size
/// photographs on the UI thread would freeze the screen.

/// Compared at one size, so a closer shot doesn't score higher just for holding
/// more pixels.
const int _sharpnessLongEdge = 1200;

const int _cropJpegQuality = 95;

/// Big enough to judge a photograph on a phone's screen, small enough to keep.
const int _previewLongEdge = 1200;
const int _previewJpegQuality = 80;

/// Laplacian variance of each shot, keyed by path. Higher is sharper.
Map<String, double> measureSharpness(List<String> paths) {
  final scores = <String, double>{};
  for (final path in paths) {
    final image = cv.imread(path, flags: cv.IMREAD_GRAYSCALE);
    try {
      if (image.rows == 0 || image.cols == 0) {
        scores[path] = 0;
        continue;
      }
      final scale = _sharpnessLongEdge / math.max(image.rows, image.cols);
      final small = scale < 1
          ? cv.resize(image, (
              (image.cols * scale).round(),
              (image.rows * scale).round(),
            ), interpolation: cv.INTER_AREA)
          : image;
      final laplacian = cv.laplacian(small, cv.MatType.CV_64F);
      scores[path] = laplacian.variance().val1;
      laplacian.dispose();
      if (!identical(small, image)) small.dispose();
    } finally {
      image.dispose();
    }
  }
  return scores;
}

class CropRequest {
  const CropRequest({
    required this.sourcePath,
    required this.targetPath,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String sourcePath;
  final String targetPath;

  /// As fractions of the photograph as it is displayed.
  final double left;
  final double top;
  final double right;
  final double bottom;
}

class PreviewRequest {
  const PreviewRequest({required this.sourcePath, required this.targetPath});

  final String sourcePath;
  final String targetPath;
}

/// Writes a small upright copy of a photograph, for the follow-up pages to show
/// after the full one has been sent and deleted.
void makePreview(PreviewRequest request) {
  final image = cv.imread(request.sourcePath);
  try {
    if (image.rows == 0 || image.cols == 0) {
      throw StateError('shot_processing: unreadable image at ${request.sourcePath}');
    }
    final longEdge = math.max(image.rows, image.cols);
    final scale = math.min(1.0, _previewLongEdge / longEdge);
    final small = cv.resize(image, (
      (image.cols * scale).round(),
      (image.rows * scale).round(),
    ), interpolation: cv.INTER_AREA);
    final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, _previewJpegQuality]);
    try {
      if (!cv.imwrite(request.targetPath, small, params: params)) {
        throw StateError('shot_processing: could not write ${request.targetPath}');
      }
    } finally {
      params.dispose();
      small.dispose();
    }
  } finally {
    image.dispose();
  }
}

class MontageRequest {
  const MontageRequest({required this.rows, required this.targetPath});

  /// Photograph paths, row by row, each row the same length.
  final List<List<String>> rows;
  final String targetPath;
}

/// Writes the photographs of a grid side by side at a small size, to show until
/// the dashboard's stitched picture arrives. They aren't joined, only laid out.
void makeMontage(MontageRequest request) {
  final columns = request.rows.first.length;
  final cellWidth = (_previewLongEdge / columns).round();
  // A shape from the first, so all of them fit together.
  var cellHeight = 0;

  cv.Mat cell(String path) {
    final image = cv.imread(path);
    try {
      if (image.rows == 0 || image.cols == 0) {
        throw StateError('shot_processing: unreadable image at $path');
      }
      if (cellHeight == 0) cellHeight = (image.rows * cellWidth / image.cols).round();
      return cv.resize(image, (cellWidth, cellHeight), interpolation: cv.INTER_AREA);
    } finally {
      image.dispose();
    }
  }

  /// Lays [next] beside or under [soFar], and frees both.
  cv.Mat joined(cv.Mat soFar, cv.Mat next, cv.Mat Function(cv.Mat, cv.Mat) join) {
    final both = join(soFar, next);
    soFar.dispose();
    next.dispose();
    return both;
  }

  cv.Mat? montage;
  try {
    for (final row in request.rows) {
      var strip = cell(row.first);
      for (final path in row.skip(1)) {
        strip = joined(strip, cell(path), (a, b) => cv.hconcat(a, b));
      }
      final current = montage;
      montage = current == null ? strip : joined(current, strip, (a, b) => cv.vconcat(a, b));
    }

    final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, _previewJpegQuality]);
    try {
      if (!cv.imwrite(request.targetPath, montage!, params: params)) {
        throw StateError('shot_processing: could not write ${request.targetPath}');
      }
    } finally {
      params.dispose();
    }
  } finally {
    montage?.dispose();
  }
}

/// Writes the chosen part of a photograph as a JPEG. imread applies the EXIF
/// orientation, the same space the crop box was drawn in, so the saved file is
/// upright and needs no orientation tag.
void cropPhoto(CropRequest request) {
  final image = cv.imread(request.sourcePath);
  try {
    if (image.rows == 0 || image.cols == 0) {
      throw StateError('shot_processing: unreadable image at ${request.sourcePath}');
    }
    final x = (request.left * image.cols).round().clamp(0, image.cols - 1);
    final y = (request.top * image.rows).round().clamp(0, image.rows - 1);
    final right = (request.right * image.cols).round().clamp(x + 1, image.cols);
    final bottom = (request.bottom * image.rows).round().clamp(y + 1, image.rows);

    final rect = cv.Rect(x, y, right - x, bottom - y);
    final cropped = image.region(rect);
    final params = cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, _cropJpegQuality]);
    try {
      if (!cv.imwrite(request.targetPath, cropped, params: params)) {
        throw StateError('shot_processing: could not write ${request.targetPath}');
      }
    } finally {
      params.dispose();
      cropped.dispose();
      rect.dispose();
    }
  } finally {
    image.dispose();
  }
}
