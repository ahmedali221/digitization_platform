// On-device counterpart of test/manual/capture_analyzer_field_check.dart —
// same CaptureAnalyzer, same real sample wall, but run on the actual target
// platform (an Android emulator/device) rather than Windows desktop, so it
// exercises the real Android-built opencv_dart native library.
//
// The Stitch/img sample folder must be pushed to the device first (it lives
// outside this repo, so it can't be a bundled asset):
//   adb push "<repo>/Stitch/img" /data/local/tmp/stitch_img
//
// Run with:
//   flutter test integration_test/capture_analyzer_device_test.dart -d <device>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:digitization_platform/features/grid_capture/domain/entities/capture_quality.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/capture_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.webp'];
const _devicePath = '/data/local/tmp/stitch_img/img';

class _ManifestCell {
  const _ManifestCell(this.folder, this.col, this.row);
  final String folder;
  final int col;
  final int row;
}

/// `--manifest-axes col_row` — confirmed the correct reading for this
/// manifest (see test/manual/capture_analyzer_field_check.dart's doc
/// comment for how that was established).
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('CaptureAnalyzer scores the Stitch/img sample wall sensibly on-device', () {
    final imgRoot = Directory(_devicePath);
    if (!imgRoot.existsSync()) {
      fail(
        'Sample data not found at $_devicePath on this device — push it first:\n'
        '  adb push "<repo>/Stitch/img" /data/local/tmp/stitch_img',
      );
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
    print('loaded ${imagePathByFolder.length}/${cells.length} cell photos from $_devicePath');

    final stopwatch = Stopwatch()..start();
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

      final cellStopwatch = Stopwatch()..start();
      final result = analyzeCellQuality(
        CellQualityRequest(
          cellIndex: indexByFolder[cell.folder]!,
          imagePath: imagePath,
          relevantEdges: relevantEdges,
          neighbours: neighbours,
        ),
      );
      cellStopwatch.stop();
      results[cell.folder] = result;

      final reason = result.failureReason;
      // ignore: avoid_print
      print(
        '${cell.folder.padRight(10)} (${cell.col},${cell.row})  '
        'image=${result.image.imageScore.toStringAsFixed(1).padLeft(5)}  '
        'cell=${result.cellScore.toStringAsFixed(1).padLeft(5)} [${result.tier.name}]  '
        '${cellStopwatch.elapsedMilliseconds}ms'
        '${reason != null ? '  -> $reason' : ''}',
      );
      for (final n in result.neighbours) {
        // ignore: avoid_print
        print(
          '    ${n.direction.name.padRight(6)} good=${n.goodMatches.toString().padLeft(3)} '
          'inliers=${n.ransacInliers.toString().padLeft(3)} '
          'ratio=${n.inlierRatio.toStringAsFixed(2)} '
          'dirOk=${n.directionOk} scaleOk=${n.scaleOk} '
          'score=${n.neighbourScore.toStringAsFixed(1)}',
        );
      }
    }
    stopwatch.stop();

    expect(results, isNotEmpty);
    for (final result in results.values) {
      expect(result.cellScore, inInclusiveRange(0, 100));
    }
    final allNeighbours = results.values.expand((r) => r.neighbours).toList();
    final agreeing = allNeighbours.where((n) => n.directionOk).length;
    // ignore: avoid_print
    print(
      '\n${results.length} cells, ${stopwatch.elapsedMilliseconds}ms total '
      '(${(stopwatch.elapsedMilliseconds / math.max(results.length, 1)).toStringAsFixed(0)}ms/cell avg) — '
      'this is the on-device Tier 1+2+3 cost the spec (§9, Q1-3) asks the developer to measure.\n'
      'direction check agreement: $agreeing/${allNeighbours.length} '
      '(${(100 * agreeing / math.max(allNeighbours.length, 1)).toStringAsFixed(0)}%)',
    );
    expect(agreeing / allNeighbours.length, greaterThan(0.5));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
