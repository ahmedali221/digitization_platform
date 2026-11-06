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

  group('deleting a photograph', () {
    test('empties its cell, deletes the file and selects the cell to refill', () async {
      cubit.resize(rows: 1, cols: 3);
      final first = photo('a.jpg');
      await cubit.addPhoto(first);
      await cubit.addPhoto(photo('b.jpg'));
      expect(cubit.state.activeCell, 2);

      await cubit.removePhoto(0);

      expect(cubit.state.photos.keys, [1]);
      expect(cubit.state.quality.keys, [1]);
      expect(cubit.state.activeCell, 0);
      expect(File(first).existsSync(), isFalse);
    });

    test('does nothing to a cell with no photograph', () async {
      cubit.resize(rows: 1, cols: 3);
      await cubit.addPhoto(photo('a.jpg'));

      await cubit.removePhoto(2);

      expect(cubit.state.photos.keys, [0]);
      expect(cubit.state.activeCell, 1);
    });

    test('clears the warning about it', () async {
      analyzer.score = 10;
      await cubit.addPhoto(photo('0.jpg'));
      await cubit.addPhoto(photo('1.jpg'));
      expect(cubit.state.weakLinks, hasLength(1));

      await cubit.removePhoto(1);

      expect(cubit.state.weakLinks, isEmpty);
      expect(cubit.state.link(0, 1), isNull);
    });

    test('a score that arrives for it afterwards is ignored', () async {
      await cubit.addPhoto(photo('0.jpg'));

      analyzer
        ..score = 10
        ..hold = Completer();
      final scoring = cubit.addPhoto(photo('1.jpg'));
      await Future<void>.delayed(Duration.zero);

      await cubit.removePhoto(1);
      analyzer.hold!.complete();
      await scoring;

      expect(cubit.state.quality.containsKey(1), isFalse);
      expect(cubit.state.weakLinks, isEmpty);
    });

    test('completes the grid again once the gap is refilled', () async {
      await cubit.addPhoto(photo('0.jpg'));
      await cubit.addPhoto(photo('1.jpg'));
      expect(cubit.state.isComplete, isTrue);

      await cubit.removePhoto(0);
      expect(cubit.state.isComplete, isFalse);

      final retaken = photo('0b.jpg');
      await cubit.addPhoto(retaken);

      expect(cubit.state.isComplete, isTrue);
      expect(cubit.state.photos[0], retaken);
    });

    test('lets the grid be resized once none are left, from its first cell', () async {
      cubit.resize(rows: 2, cols: 2);
      cubit.select(3);
      await cubit.addPhoto(photo('3.jpg'));

      await cubit.removePhoto(3);
      expect(cubit.state.activeCell, 3);

      cubit.resize(rows: 1);

      expect(cubit.state.cellCount, 2);
      expect(cubit.state.activeCell, 0);
    });
  });

  group('sending', () {
    test('hands over the whole grid, and says it did', () async {
      await cubit.addPhoto(photo('a.jpg'));
      await cubit.addPhoto(photo('b.jpg'));
      FollowUpGridState? handed;

      final sent = await cubit.send((grid) async => handed = grid);

      expect(sent, isTrue);
      expect(handed?.photos, cubit.state.photos);
      expect(handed?.sending, isTrue);
      expect(cubit.state.sending, isFalse);
    });

    test('a failure keeps every photograph, to try again', () async {
      final first = photo('a.jpg');
      final second = photo('b.jpg');
      await cubit.addPhoto(first);
      await cubit.addPhoto(second);

      const failure = FileSystemException('disk full');
      final sent = await cubit.send((_) async => throw failure);

      expect(sent, isFalse);
      expect(cubit.state.sending, isFalse);
      expect(cubit.state.sendError, failure);
      expect(cubit.state.photos, {0: first, 1: second});
      expect(File(first).existsSync(), isTrue);
      expect(File(second).existsSync(), isTrue);
    });

    test('says why it failed until the next attempt, whatever scores arrive', () async {
      await cubit.addPhoto(photo('a.jpg'));
      await cubit.send((_) async => throw const FileSystemException('disk full'));

      await cubit.addPhoto(photo('b.jpg'));
      expect(cubit.state.sendError, isNotNull);

      final holding = Completer<void>();
      final retry = cubit.send((_) => holding.future);
      expect(cubit.state.sendError, isNull);

      holding.complete();
      expect(await retry, isTrue);
      expect(cubit.state.sendError, isNull);
    });

    test('a second tap while on its way does not send it twice', () async {
      final holding = Completer<void>();
      var queued = 0;
      Future<void> queue(FollowUpGridState _) {
        queued++;
        return holding.future;
      }

      final first = cubit.send(queue);
      final second = await cubit.send(queue);

      expect(second, isFalse);
      expect(queued, 1);

      holding.complete();
      expect(await first, isTrue);
    });

    test('closing the page meanwhile is harmless', () async {
      final holding = Completer<void>();
      final sending = cubit.send((_) => holding.future);

      await cubit.close();
      holding.complete();

      expect(await sending, isTrue);
    });
  });

  group('the cell the camera offers to open', () {
    test('is none before the first photograph', () {
      expect(cubit.state.reviewableCell, isNull);
    });

    test('is the latest taken, once the camera has moved on to an empty cell', () async {
      cubit.resize(rows: 1, cols: 3);
      await cubit.addPhoto(photo('a.jpg'));

      expect(cubit.state.activeCell, 1);
      expect(cubit.state.reviewableCell, 0);
    });

    test('is the selected cell, when that has a photograph', () async {
      cubit.resize(rows: 1, cols: 3);
      await cubit.addPhoto(photo('a.jpg'));
      await cubit.addPhoto(photo('b.jpg'));

      cubit.select(0);

      expect(cubit.state.reviewableCell, 0);
    });

    test('is none once the latest has been deleted', () async {
      cubit.resize(rows: 1, cols: 3);
      await cubit.addPhoto(photo('a.jpg'));
      await cubit.addPhoto(photo('b.jpg'));

      await cubit.removePhoto(1);

      expect(cubit.state.reviewableCell, isNull);
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
