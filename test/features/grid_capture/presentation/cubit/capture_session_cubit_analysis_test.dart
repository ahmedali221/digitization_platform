// The capture screen froze because quality analysis ran on the main isolate.
// These pin down how CaptureSessionCubit behaves now that analysis really is
// asynchronous. The analyzer is a fake, so no OpenCV is involved.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:digitization_platform/core/domain/entities/wall.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:digitization_platform/features/grid_capture/data/datasources/grid_capture_local_data_source.dart';
import 'package:digitization_platform/features/grid_capture/domain/entities/capture_quality.dart';
import 'package:digitization_platform/features/grid_capture/domain/repositories/grid_capture_repository.dart';
import 'package:digitization_platform/features/grid_capture/domain/services/cell_quality_analyzer.dart';
import 'package:digitization_platform/features/grid_capture/presentation/cubit/capture_session_cubit.dart';
import 'package:digitization_platform/features/grid_capture/presentation/cubit/capture_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _floor = 'floor';
const _wall = 'wall';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAnalyzer analyzer;
  late _FakeRepository repository;
  late CaptureSessionCubit cubit;

  CaptureSessionLoaded loaded() => cubit.state as CaptureSessionLoaded;

  setUp(() async {
    analyzer = _FakeAnalyzer();
    repository = _FakeRepository(rows: 1, cols: 2);
    cubit = CaptureSessionCubit(repository, _FakeLocalDataSource(), analyzer)
      ..init(_floor, _wall)
      ..openCell(0);
    cubit.refresh();
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test('takePhoto returns while analysis is still running', () async {
    await cubit.takePhoto(XFile('shot.jpg'));

    expect(analyzer.requests, hasLength(1));
    expect(analyzer.isIdle, isFalse);
    expect(loaded().analyzingCellIds, {0});
    expect(loaded().cellQuality, isEmpty);

    await analyzer.finishAll();

    expect(loaded().cellQuality.keys, [0]);
    expect(loaded().analyzingCellIds, isEmpty);
    expect(repository.recorded.keys, [0]);
  });

  test('a shot taken mid-analysis is scored, and the old result is dropped', () async {
    await cubit.takePhoto(XFile('first.jpg'));
    await cubit.takePhoto(XFile('second.jpg'));

    // One at a time: the second shot waits for the first run to end.
    expect(analyzer.requests, hasLength(1));
    expect(analyzer.requests.single.imagePaths, hasLength(1));

    await analyzer.finishNext();

    expect(loaded().cellQuality, isEmpty, reason: 'scored only the first shot');
    expect(analyzer.requests, hasLength(2));
    expect(analyzer.requests.last.imagePaths, hasLength(2));

    await analyzer.finishAll();

    expect(loaded().cellQuality[0]!.imagePath, analyzer.requests.last.imagePaths.first);
    expect(repository.recorded[0], isNotNull);
    expect(loaded().analyzingCellIds, isEmpty);
  });

  test('a deleted shot\'s result is discarded and the cell scored again', () async {
    await cubit.takePhoto(XFile('first.jpg'));
    final firstPath = repository.shotPaths(0).single;
    await cubit.takePhoto(XFile('second.jpg'));
    await analyzer.finishNext();
    await analyzer.finishNext();
    await cubit.takePhoto(XFile('third.jpg'));

    await cubit.deletePhoto(0, firstPath);
    await analyzer.finishAll();

    expect(analyzer.requests.last.imagePaths, isNot(contains(firstPath)));
    expect(loaded().cellQuality[0]!.imagePath, isNot(firstPath));
  });

  test('deleting a cell\'s last shot mid-analysis leaves it with no score', () async {
    await cubit.takePhoto(XFile('only.jpg'));
    final path = repository.shotPaths(0).single;

    await cubit.deletePhoto(0, path);
    await analyzer.finishAll();

    expect(loaded().cellQuality, isEmpty);
    expect(loaded().analyzingCellIds, isEmpty);
    expect(repository.recorded, isEmpty);
  });

  test('a new shot rescores its captured neighbour, after the cell itself', () async {
    await cubit.takePhoto(XFile('left.jpg'));
    await analyzer.finishAll();
    cubit.openCell(1);
    await cubit.takePhoto(XFile('right.jpg'));
    await analyzer.finishAll();

    expect(analyzer.requests.map((r) => r.cellIndex), [0, 1, 0]);
    expect(analyzer.requests[1].neighbours.single.cellIndex, 0);
    expect(repository.recorded.keys.toSet(), {0, 1});
  });

  test('closing mid-analysis does not throw and the score is still saved', () async {
    await cubit.takePhoto(XFile('shot.jpg'));

    await cubit.close();
    await analyzer.finishAll();

    expect(repository.recorded.keys, [0]);
  });

  test('a failed analysis clears the analyzing state and saves nothing', () async {
    await cubit.takePhoto(XFile('shot.jpg'));

    await analyzer.failNext();

    expect(loaded().analyzingCellIds, isEmpty);
    expect(loaded().cellQuality, isEmpty);
    expect(repository.recorded, isEmpty);

    // The queue isn't stuck: the next shot is analyzed normally.
    await cubit.takePhoto(XFile('retake.jpg'));
    await analyzer.finishAll();
    expect(loaded().cellQuality.keys, [0]);
  });
}

/// Holds each request until the test releases it.
class _FakeAnalyzer implements CellQualityAnalyzer {
  final List<CellQualityRequest> requests = [];
  final List<Completer<CellQualityResult>> _waiting = [];

  bool get isIdle => _waiting.isEmpty;

  @override
  Future<CellQualityResult> analyze(CellQualityRequest request) {
    requests.add(request);
    final completer = Completer<CellQualityResult>();
    _waiting.add(completer);
    return completer.future;
  }

  Future<void> finishNext() async {
    final request = requests[requests.length - _waiting.length];
    _waiting.removeAt(0).complete(_resultFor(request));
    await pumpEventQueue();
  }

  Future<void> failNext() async {
    _waiting.removeAt(0).completeError(StateError('analysis failed'));
    await pumpEventQueue();
  }

  Future<void> finishAll() async {
    await pumpEventQueue();
    while (_waiting.isNotEmpty) {
      await finishNext();
    }
  }

  CellQualityResult _resultFor(CellQualityRequest request) => CellQualityResult(
    cellIndex: request.cellIndex,
    imagePath: request.imagePaths.first,
    image: const ImageQualityMetrics(
      keypointCount: 1000,
      keypointDensity: 500,
      spatialDistribution: 1,
      edgeKeypoints: {},
      relevantEdgeDensity: 500,
      sharpness: 500,
      contrast: 60,
      imageScore: 100,
    ),
    neighbours: const [],
    cellScore: 100,
    tier: QualityTier.green,
    failureReason: null,
    computedAt: DateTime(2026),
  );
}

/// An in-memory wall, with only what the cubit uses in these tests.
class _FakeRepository implements GridCaptureRepository {
  _FakeRepository({required int rows, required int cols})
    : _rows = rows,
      _cols = cols,
      _shots = List.generate(rows * cols, (_) => <String>[]);

  final int _rows;
  final int _cols;
  final List<List<String>> _shots;
  final Map<int, CellQualityResult> recorded = {};

  List<String> shotPaths(int cell) => _shots[cell];

  WallEntity _wallEntity() => WallEntity(
    id: _wall,
    floorId: _floor,
    name: _wall,
    status: WallStatus.values.first,
    lastCapture: '',
    grid: GridState(
      rows: _rows,
      cols: _cols,
      cells: [for (final shots in _shots) GridCell(shotPaths: List.of(shots))],
    ),
  );

  @override
  WallEntity? getWall(String floorId, String wallId) => _wallEntity();

  @override
  Stream<WallEntity?> watchWall(String floorId, String wallId) => Stream.value(_wallEntity());

  @override
  Map<int, CellQualityResult> getCellQuality(String floorId, String wallId) => {};

  @override
  bool getCellQualityOverridden(String floorId, String wallId, int cellIndex) => false;

  @override
  WallEntity? capturePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath, {
    String? sha256,
    int? shot,
  }) {
    _shots[cellIndex].add(filePath);
    return _wallEntity();
  }

  @override
  Future<WallEntity?> deletePhoto(
    String floorId,
    String wallId,
    int cellIndex,
    String filePath,
  ) async {
    _shots[cellIndex].remove(filePath);
    return _wallEntity();
  }

  @override
  void recordCellQualityBatch(
    String floorId,
    String wallId,
    Map<int, CellQualityResult> results,
  ) => recorded.addAll(results);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalDataSource extends GridCaptureLocalDataSource {
  var _saved = 0;

  @override
  Future<({String path, String sha256})> saveShot({
    required String wallId,
    required int row,
    required int col,
    required int shotNumber,
    required XFile capturedFile,
  }) async => (path: '/photos/R${row}C${col}_S${_saved++}.jpg', sha256: 'checksum');
}
