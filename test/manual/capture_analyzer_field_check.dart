// Manual verification, not a CI test: runs CaptureAnalyzer (the same code
// path the app dispatches via compute()) directly against the real sample
// wall in Stitch/img/, using its manifesto.json for grid adjacency exactly
// the way stitch.py's `load_manifest` (--manifest-axes row_colR, the
// default) does. Skips itself if that folder isn't present on this
// machine — the sample data lives outside this repo.
//
// Run with:  flutter test test/manual/capture_analyzer_field_check.dart
//
// This is the fast, no-emulator way to sanity-check the ported SIFT/RANSAC
// logic: opencv_dart runs on Windows desktop too, so this exercises the
// real OpenCV core stitch.py itself calls, on real capture photos, without
// touching the app's camera UI at all.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:digitization_platform/features/grid_capture/domain/entities/capture_quality.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/capture_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.webp'];

class _ManifestCell {
  const _ManifestCell(this.folder, this.col, this.row);
  final String folder;
  final int col;
  final int row;
}

/// Mirrors stitch.py's `load_manifest` under `--manifest-axes col_row`
/// (x=column, y=row directly) — confirmed the correct reading for THIS
/// manifest via `python stitch.py -f img --audit-only --manifest-axes
/// col_row`: 37/37 claimed adjacencies agree with the pixels. The default
/// `row_colR` axes disagrees on all 37 (a systematic below<->right swap),
/// despite stitch.py's own header comment describing img/manifesto.json as
/// row_colR-authored — this sample data just isn't that anymore.
List<_ManifestCell> _parseManifest(Map<String, dynamic> json) {
  final raw = (json['cells'] as List)
      .cast<Map<String, dynamic>>()
      .map((e) => (folder: e['folder'] as String, x: e['x'] as int, y: e['y'] as int));
  return [for (final e in raw) _ManifestCell(e.folder, e.x, e.y)];
}

String? _pickImage(Directory folderDir) {
  if (!folderDir.existsSync()) return null;
  final files = folderDir
      .listSync()
      .whereType<File>()
      .where((f) => _imageExtensions.contains(p.extension(f.path).toLowerCase()))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) return null;
  final main = files.where((f) => p.basenameWithoutExtension(f.path).toLowerCase() == 'main');
  return (main.isNotEmpty ? main.first : files.first).path;
}

(int, int) _delta(NeighbourDirection direction) => switch (direction) {
  NeighbourDirection.left => (-1, 0),
  NeighbourDirection.right => (1, 0),
  NeighbourDirection.top => (0, -1),
  NeighbourDirection.bottom => (0, 1),
};

void main() {
  test('CaptureAnalyzer scores the Stitch/img sample wall sensibly', () {
    final imgRoot = Directory(p.join(Directory.current.path, '..', 'Stitch', 'img'));
    if (!imgRoot.existsSync()) {
      // ignore: avoid_print
      print('SKIP: ${imgRoot.path} not present on this machine.');
      return;
    }

    final manifestJson =
        jsonDecode(File(p.join(imgRoot.path, 'manifesto.json')).readAsStringSync()) as Map<String, dynamic>;
    final cells = _parseManifest(manifestJson);
    final byPosition = {for (final c in cells) (c.col, c.row): c.folder};
    final indexByFolder = {for (var i = 0; i < cells.length; i++) cells[i].folder: i};

    final imagePathByFolder = <String, String>{};
    for (final cell in cells) {
      final path = _pickImage(Directory(p.join(imgRoot.path, cell.folder)));
      if (path != null) imagePathByFolder[cell.folder] = path;
    }

    // ignore: avoid_print
    print(
      'grid: ${cells.length} cells, '
      '${cells.map((c) => c.col).reduce(math.max) + 1} cols x '
      '${cells.map((c) => c.row).reduce(math.max) + 1} rows\n',
    );

    final results = <String, CellQualityResult>{};
    for (final cell in cells) {
      final imagePath = imagePathByFolder[cell.folder];
      if (imagePath == null) continue;

      final relevantEdges = <EdgeSide>{};
      final neighbours = <NeighbourImageInput>[];
      for (final direction in NeighbourDirection.values) {
        final (dc, dr) = _delta(direction);
        final neighbourFolder = byPosition[(cell.col + dc, cell.row + dr)];
        if (neighbourFolder == null) continue;
        relevantEdges.add(direction.edge);
        final neighbourPath = imagePathByFolder[neighbourFolder];
        if (neighbourPath == null) continue;
        neighbours.add(
          NeighbourImageInput(
            direction: direction,
            cellIndex: indexByFolder[neighbourFolder]!,
            imagePath: neighbourPath,
          ),
        );
      }

      final result = analyzeCellQuality(
        CellQualityRequest(
          cellIndex: indexByFolder[cell.folder]!,
          imagePaths: [imagePath],
          relevantEdges: relevantEdges,
          neighbours: neighbours,
        ),
      );
      results[cell.folder] = result;

      final reason = result.failureReason;
      // ignore: avoid_print
      print(
        '${cell.folder.padRight(10)} (${cell.col},${cell.row})  '
        'image=${result.image.imageScore.toStringAsFixed(1).padLeft(5)}  '
        'cell=${result.cellScore.toStringAsFixed(1).padLeft(5)} [${result.tier.name}]'
        '${reason != null ? '  -> $reason' : ''}',
      );
      for (final n in result.neighbours) {
        // ignore: avoid_print
        print(
          '    ${n.direction.name.padRight(6)} good=${n.goodMatches.toString().padLeft(3)} '
          'inliers=${n.ransacInliers.toString().padLeft(3)} '
          'ratio=${n.inlierRatio.toStringAsFixed(2)} '
          'dx=${n.dx.toStringAsFixed(0).padLeft(5)} dy=${n.dy.toStringAsFixed(0).padLeft(5)} '
          'scale=${n.scale.toStringAsFixed(2)} '
          'dirOk=${n.directionOk} scaleOk=${n.scaleOk} '
          'score=${n.neighbourScore.toStringAsFixed(1)}',
        );
      }
    }

    expect(results, isNotEmpty);
    for (final result in results.values) {
      expect(result.cellScore, inInclusiveRange(0, 100));
      expect(result.image.imageScore, inInclusiveRange(0, 100));
      for (final n in result.neighbours) {
        expect(n.neighbourScore, inInclusiveRange(0, 100));
        expect(n.inlierRatio, inInclusiveRange(0, 1));
      }
    }

    final allNeighbours = results.values.expand((r) => r.neighbours).toList();
    expect(allNeighbours, isNotEmpty);
    final agreeing = allNeighbours.where((n) => n.directionOk).length;
    // ignore: avoid_print
    print(
      '\ndirection check agreement: $agreeing/${allNeighbours.length} '
      '(${(100 * agreeing / allNeighbours.length).toStringAsFixed(0)}%)',
    );
    // stitch.py's own comment on this exact manifest: under row_colR (the
    // default), every claimed adjacency agrees with the pixels. A ported
    // implementation that's actually correct should land close to that,
    // not just "not crash" - this is a deliberately generous floor so a
    // handful of genuinely weak/blurry sample shots don't make the check
    // flaky, while still catching a fundamentally broken port.
    expect(agreeing / allNeighbours.length, greaterThan(0.5));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
