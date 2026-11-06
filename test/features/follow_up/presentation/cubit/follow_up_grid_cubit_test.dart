import 'dart:async';
import 'dart:io';

import 'package:digitization_platform/features/follow_up/presentation/cubit/follow_up_grid_cubit.dart';
import 'package:digitization_platform/features/grid_capture/domain/entities/capture_quality.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/cell_quality_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Answers with [score] for every neighbour a photograph was compared to.
class _FakeAnalyzer implements CellQualityAnalyzer {
  double score = 90;
  final List<CellQualityRequest> requests = [];
  Completer<void>? hold;

  @override
  Future<CellQualityResult> analyze(CellQualityRequest request) async {
    requests.add(request);
    if (hold != null) await hold!.future;
    return CellQualityResult(
      cellIndex: request.cellIndex,
      imagePath: request.imagePaths.first,
      image: const ImageQualityMetrics(
        keypointCount: 1,
        keypointDensity: 1,
        spatialDistribution: 1,
        edgeKeypoints: {},
        relevantEdgeDensity: 1,
        sharpness: 1,
        contrast: 1,
        imageScore: 90,
      ),
      neighbours: [
        for (final neighbour in request.neighbours)
          NeighbourMatchMetrics(
            direction: neighbour.direction,
            neighbourCellIndex: neighbour.cellIndex,
            goodMatches: 1,
            ransacInliers: 1,
            inlierRatio: 1,
            dx: 0,
            dy: 0,
            scale: 1,
            directionOk: true,
            scaleOk: true,
            neighbourScore: score,
          ),
      ],
      cellScore: score,
      tier: QualityTier.green,
      failureReason: null,
      computedAt: DateTime(2026),
    );
  }
}

void main() {
  late _FakeAnalyzer analyzer;
  late FollowUpGridCubit cubit;
  late Directory folder;

  setUp(() {
    analyzer = _FakeAnalyzer();
    cubit = FollowUpGridCubit(analyzer);
    folder = Directory.systemTemp.createTempSync('follow_up_grid_');
  });

  tearDown(() async {
    await cubit.close();
    folder.deleteSync(recursive: true);
  });

  String photo(String name) {
    final path = p.join(folder.path, name);
    File(path).writeAsStringSync('jpeg');
    return path;
  }

  group('its size', () {
    test('stays inside what the dashboard accepts', () {
      cubit.resize(rows: 7);
      expect(cubit.state.rows, 1);

      cubit.resize(rows: 5, cols: 5);
      expect(cubit.state.cellCount, 2, reason: '25 cells is over the limit of 24');

      cubit.resize(rows: 4, cols: 6);
      expect(cubit.state.cellCount, 24);

      cubit.resize(rows: 0);
      expect(cubit.state.rows, 4);
    });

    test('needs at least two cells', () {
      cubit.resize(cols: 1);
      expect(cubit.state.cols, 2);
    });

    test('is fixed from the first photograph on', () async {
      await cubit.addPhoto(photo('a.jpg'));

      cubit.resize(rows: 3);

      expect(cubit.state.rows, 1);
    });
  });

  group('taking photographs', () {
    test('moves on to the next empty cell, and goes back for a skipped one', () async {
      cubit.resize(rows: 1, cols: 3);

      cubit.select(1);
      await cubit.addPhoto(photo('b.jpg'));
      expect(cubit.state.activeCell, 2);

      await cubit.addPhoto(photo('c.jpg'));
      expect(cubit.state.activeCell, 0);
      expect(cubit.state.isComplete, isFalse);

      await cubit.addPhoto(photo('a.jpg'));
      expect(cubit.state.isComplete, isTrue);
    });

    test('a retake replaces the photograph and deletes the old file', () async {
      final first = photo('a.jpg');
      await cubit.addPhoto(first);
      cubit.select(0);

      final second = photo('a2.jpg');
      await cubit.addPhoto(second);

      expect(cubit.state.photos, {0: second});
      expect(File(first).existsSync(), isFalse);
    });
  });

  group('overlap', () {
    test('compares a photograph with the neighbours taken so far, and only those', () async {
      cubit.resize(rows: 2, cols: 2);
      await cubit.addPhoto(photo('0.jpg'));
      expect(analyzer.requests.last.neighbours, isEmpty);
      expect(analyzer.requests.last.relevantEdges, {EdgeSide.right, EdgeSide.bottom});

      await cubit.addPhoto(photo('1.jpg'));
      expect(analyzer.requests.last.neighbours.map((n) => n.cellIndex), [0]);

      cubit.select(3);
      await cubit.addPhoto(photo('3.jpg'));
      expect(analyzer.requests.last.neighbours.map((n) => n.cellIndex), [1]);
      expect(analyzer.requests.last.relevantEdges, {EdgeSide.left, EdgeSide.top});
    });

    test('a pair that hardly matches is a weak link, named by its two cells', () async {
      analyzer.score = 10;
      cubit.resize(rows: 2, cols: 2);
      await cubit.addPhoto(photo('0.jpg'));
      await cubit.addPhoto(photo('1.jpg'));
      cubit.select(2);
      await cubit.addPhoto(photo('2.jpg'));

      expect(cubit.state.weakLinks, unorderedEquals([(from: 0, to: 1), (from: 0, to: 2)]));
      expect(cubit.state.link(1, 0)?.neighbourScore, 10);
    });

    test('a good pair is not', () async {
      await cubit.addPhoto(photo('0.jpg'));
      await cubit.addPhoto(photo('1.jpg'));

      expect(cubit.state.link(0, 1), isNotNull);
      expect(cubit.state.weakLinks, isEmpty);
    });

    test('retaking a cell clears the warning about it', () async {
      analyzer.score = 10;
      await cubit.addPhoto(photo('0.jpg'));
      await cubit.addPhoto(photo('1.jpg'));
      expect(cubit.state.weakLinks, hasLength(1));

      analyzer.score = 90;
      cubit.select(1);
      await cubit.addPhoto(photo('1b.jpg'));

      expect(cubit.state.weakLinks, isEmpty);
    });

    test('a score for a photograph since retaken is ignored', () async {
      analyzer.score = 10;
      await cubit.addPhoto(photo('0.jpg'));

      analyzer.hold = Completer();
      cubit.select(1);
      final scoring = cubit.addPhoto(photo('1.jpg'));
      await Future<void>.delayed(Duration.zero);

      analyzer.score = 90;
      cubit.select(1);
      final retake = cubit.addPhoto(photo('1b.jpg'));

      analyzer.hold!.complete();
      await Future.wait([scoring, retake]);

      expect(cubit.state.weakLinks, isEmpty);
    });

    test('an analysis that fails costs only the warning', () async {
      final broken = FollowUpGridCubit(_BrokenAnalyzer());
      addTearDown(broken.close);

      await broken.addPhoto(photo('0.jpg'));

      expect(broken.state.photos, hasLength(1));
      expect(broken.state.weakLinks, isEmpty);
    });
  });
}

class _BrokenAnalyzer implements CellQualityAnalyzer {
  @override
  Future<CellQualityResult> analyze(CellQualityRequest request) async => throw StateError('no');
}
