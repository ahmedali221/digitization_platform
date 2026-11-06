import 'dart:io';

import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_local_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_remote_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/domain/services/follow_up_upload_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeLocal implements FollowUpLocalDataSource {
  final Map<String, FollowUpUploadRecord> records = {};

  @override
  List<FollowUpUploadRecord> all() => records.values.toList();

  @override
  Future<void> put(FollowUpUploadRecord record) async => records[record.token] = record;

  @override
  Future<void> delete(String token) async => records.remove(token);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements FollowUpRemoteDataSource {
  final List<String> uploaded = [];
  final List<String> widthsUploaded = [];
  final Map<String, Object> failures = {};
  List<Map<String, dynamic>> answers = [];
  Future<void>? hold;

  @override
  Future<void> upload(
    FollowUpUploadRecord record, {
    required Stream<List<int>> Function() openBytes,
    required int length,
  }) async {
    if (hold != null) await hold;
    final failure = failures[record.token];
    if (failure != null) throw failure;
    uploaded.add(record.token);
  }

  @override
  Future<void> uploadWidth(FollowUpUploadRecord record) async {
    final failure = failures[record.token];
    if (failure != null) throw failure;
    widthsUploaded.add(record.token);
  }

  final List<String> gridsRegistered = [];
  final List<String> tilesSent = [];
  Object? tileFailure;
  int tilesBeforeFailure = 0;
  Map<String, dynamic> decisionAnswer = const {};
  final List<bool> decisions = [];
  final List<String> previewsAsked = [];
  Object? previewFailure;

  @override
  Future<void> registerGrid(FollowUpUploadRecord record) async {
    final failure = failures[record.token];
    if (failure != null) throw failure;
    gridsRegistered.add(record.token);
  }

  @override
  Future<void> uploadGridTile(
    String token,
    GridTile tile, {
    required Stream<List<int>> Function() openBytes,
    required int length,
  }) async {
    if (tileFailure != null && tilesSent.length >= tilesBeforeFailure) throw tileFailure!;
    tilesSent.add('r${tile.row}c${tile.col}');
  }

  @override
  Future<Map<String, dynamic>> decideGrid(String token, {required bool use}) async {
    final failure = failures[token];
    if (failure != null) throw failure;
    decisions.add(use);
    return decisionAnswer;
  }

  @override
  Future<void> downloadGridPreview(String token, String savePath) async {
    previewsAsked.add(token);
    if (previewFailure != null) throw previewFailure!;
    File(savePath).writeAsStringSync('stitched');
  }

  @override
  Future<List<Map<String, dynamic>>> results(List<String> tokens) async =>
      answers.where((a) => tokens.contains(a['token'])).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory folder;
  late _FakeLocal local;
  late _FakeRemote remote;
  late FollowUpUploadRunner runner;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('follow_up_runner_');
    local = _FakeLocal();
    remote = _FakeRemote();
    runner = FollowUpUploadRunner(
      local: local,
      remote: remote,
      resolveFile: (path) async => await File(path).exists() ? File(path) : null,
    );
  });

  tearDown(() => folder.deleteSync(recursive: true));

  FollowUpUploadRecord queuedGrid(String token, {List<(int, int)> cells = const [(0, 0), (0, 1), (0, 2)]}) {
    final record = FollowUpUploadRecord(
      token: token,
      kind: FollowUpUploadRecord.kindAnnotationGrid,
      siteId: '1',
      packageId: 1,
      itemKey: '5',
      label: 'W-1',
      filePath: '',
      sha256: '',
      capturedAt: DateTime(2026),
      createdAt: DateTime(2026),
      rows: 1,
      cols: cells.length,
    )..tiles = [
      for (final (row, col) in cells)
        GridTile(row: row, col: col, path: p.join(folder.path, '${token}_r${row}c$col.jpg'), sha256: 'abc'),
    ];
    for (final tile in record.tiles) {
      File(tile.path).writeAsStringSync('photo');
    }
    local.records[token] = record;
    return record;
  }

  FollowUpUploadRecord queued(String token, {bool withFile = true}) {
    final path = p.join(folder.path, '$token.jpg');
    if (withFile) File(path).writeAsStringSync('photo');
    final record = FollowUpUploadRecord(
      token: token,
      kind: FollowUpUploadRecord.kindAnnotation,
      siteId: '1',
      packageId: 1,
      itemKey: '5',
      label: 'W-1',
      filePath: path,
      sha256: 'abc',
      capturedAt: DateTime(2026),
      createdAt: DateTime(2026),
    );
    local.records[token] = record;
    return record;
  }

  FollowUpUploadRecord queuedWidth(String token) {
    final record = FollowUpUploadRecord(
      token: token,
      kind: FollowUpUploadRecord.kindWidth,
      siteId: '1',
      packageId: 1,
      itemKey: 'abcdefghij',
      label: 'Wall-1',
      filePath: '',
      sha256: '',
      capturedAt: DateTime(2026),
      createdAt: DateTime(2026),
      physicalWidthM: 1.42,
      widthSource: 'ar',
    );
    local.records[token] = record;
    return record;
  }

  test('a width goes with no file to look for', () async {
    final record = queuedWidth('w');

    await runner.drainAll();

    expect(remote.widthsUploaded, ['w']);
    expect(remote.uploaded, isEmpty);
    expect(record.status, FollowUpUploadRecord.statusSent);
  });

  test('a width refused because the image changed since says why and is not retried', () async {
    final record = queuedWidth('w');
    remote.failures['w'] = const AppException(ServerFailure(409, 'Measure it again.'));

    await runner.drainAll();
    await runner.drainAll();

    expect(record.status, FollowUpUploadRecord.statusFailed);
    expect(record.lastError, 'Measure it again.');
    expect(record.attempts, 1);
  });

  test('a width with no connection waits, and goes on the next drain', () async {
    final record = queuedWidth('w');
    remote.failures['w'] = const AppException(NetworkFailure());

    await runner.drainAll();
    expect(record.status, FollowUpUploadRecord.statusQueued);

    remote.failures.clear();
    await runner.drainAll();
    expect(record.status, FollowUpUploadRecord.statusSent);
  });

  test('a width settling has no file to clean up', () async {
    final record = queuedWidth('w');
    var looked = false;
    final watching = FollowUpUploadRunner(
      local: local,
      remote: remote,
      resolveFile: (path) async {
        looked = true;
        return null;
      },
    );
    remote.answers = [
      {'token': 'w', 'status': 'pushed'},
    ];

    await watching.drainAll();

    expect(record.serverStatus, 'pushed');
    expect(looked, isFalse);
  });

  test('sends what is queued and marks it sent', () async {
    final record = queued('a');

    await runner.drainAll();

    expect(remote.uploaded, ['a']);
    expect(record.status, FollowUpUploadRecord.statusSent);
    expect(record.lastError, isNull);
  });

  test('sends each once: what is already sent is not sent again', () async {
    queued('a');

    await runner.drainAll();
    await runner.drainAll();

    expect(remote.uploaded, ['a']);
  });

  test('a second drain while one is running does not send it twice', () async {
    queued('a');
    final held = Future<void>.delayed(const Duration(milliseconds: 20));
    remote.hold = held;

    await Future.wait([runner.drainAll(), runner.drainAll()]);

    expect(remote.uploaded, ['a']);
  });

  test('an upload cut off halfway, left as uploading, is sent on the next drain', () async {
    final record = queued('a')..status = FollowUpUploadRecord.statusUploading;

    await runner.drainAll();

    expect(remote.uploaded, ['a']);
    expect(record.status, FollowUpUploadRecord.statusSent);
  });

  test('no connection keeps it queued and stops trying the rest', () async {
    final first = queued('a');
    queued('b');
    remote.failures['a'] = const AppException(NetworkFailure());

    await runner.drainAll();

    expect(first.status, FollowUpUploadRecord.statusQueued);
    expect(first.attempts, 1);
    expect(remote.uploaded, isEmpty);
  });

  test('a refusal is not retried, says why, and the next one still goes', () async {
    for (final failure in <Failure>[
      const ValidationFailure('An image set takes no capture.', {}),
      const ServerFailure(403, 'Not allowed.'),
      const ServerFailure(404, 'Not found.'),
      const ServerFailure(409, 'Conflict.'),
      const ServerFailure(422, 'Refused.'),
    ]) {
      local.records.clear();
      remote.uploaded.clear();
      final refused = queued('a');
      queued('b');
      remote.failures['a'] = AppException(failure);

      await runner.drainAll();
      await runner.drainAll();

      expect(refused.status, FollowUpUploadRecord.statusFailed, reason: failure.message);
      expect(refused.lastError, failure.message);
      expect(refused.attempts, 1, reason: failure.message);
      expect(remote.uploaded, ['b'], reason: failure.message);
    }
  });

  test('a file that arrived damaged (400) and a server error stay queued to retry', () async {
    for (final failure in <Failure>[const ServerFailure(400, 'Damaged.'), const ServerFailure(500, 'Down.')]) {
      local.records.clear();
      final record = queued('a');
      remote.failures['a'] = AppException(failure);

      await runner.drainAll();

      expect(record.status, FollowUpUploadRecord.statusQueued, reason: failure.message);
    }
  });

  test('an expired session keeps it queued for after signing in again', () async {
    final record = queued('a');
    remote.failures['a'] = const AppException(UnauthorizedFailure());

    await runner.drainAll();

    expect(record.status, FollowUpUploadRecord.statusQueued);
  });

  test('a photograph no longer on the phone fails and asks for another', () async {
    final record = queued('a', withFile: false);

    await runner.drainAll();

    expect(record.status, FollowUpUploadRecord.statusFailed);
    expect(remote.uploaded, isEmpty);
  });

  test('collects a result, and drops the file once nothing more can happen to it', () async {
    final record = queued('a');
    remote.answers = [
      {
        'token': 'a',
        'status': 'reverted',
        'grade': 'failed',
        'baseline_grade': 'weak',
        'reasons': <String>[],
      },
    ];

    await runner.drainAll();

    expect(record.serverStatus, 'reverted');
    expect(record.grade, 'failed');
    expect(record.baselineGrade, 'weak');
    expect(File(record.filePath).existsSync(), isFalse);
  });

  test('keeps the file and goes on asking while it is still being decided', () async {
    final record = queued('a');
    remote.answers = [
      {'token': 'a', 'status': 'pending_review', 'reject_reason': null},
    ];

    await runner.drainAll();
    expect(record.serverStatus, 'pending_review');
    expect(File(record.filePath).existsSync(), isTrue);

    remote.answers = [
      {'token': 'a', 'status': 'rejected', 'reject_reason': 'Too dark'},
    ];
    await runner.refreshResults();

    expect(record.serverStatus, 'rejected');
    expect(record.rejectReason, 'Too dark');
    expect(File(record.filePath).existsSync(), isFalse);
  });

  test('a photograph waiting at the studio is kept and asked about again', () async {
    final record = queued('a');
    remote.answers = [
      {'token': 'a', 'status': 'pushed'},
    ];

    await runner.drainAll();
    expect(record.serverStatus, 'pushed');
    expect(File(record.filePath).existsSync(), isTrue);

    remote.answers = [
      {'token': 'a', 'status': 'studio_approved'},
    ];
    await runner.refreshResults();

    expect(record.serverStatus, 'studio_approved');
    expect(File(record.filePath).existsSync(), isFalse);
  });

  test('a photograph turned down at any stage is final, with the reason', () async {
    for (final status in ['refused', 'studio_rejected']) {
      local.records.clear();
      final record = queued('a');
      remote.answers = [
        {'token': 'a', 'status': status, 'reject_reason': 'Another was chosen.'},
      ];

      await runner.drainAll();

      expect(record.rejectReason, 'Another was chosen.', reason: status);
      expect(File(record.filePath).existsSync(), isFalse, reason: status);
    }
  });

  test('deleting a finished photograph leaves its small copy to show', () async {
    final path = p.join(folder.path, 'a.jpg');
    final preview = p.join(folder.path, 'a-preview.jpg');
    File(path).writeAsStringSync('photo');
    File(preview).writeAsStringSync('small');
    local.records['a'] = FollowUpUploadRecord(
      token: 'a',
      kind: FollowUpUploadRecord.kindTarget,
      siteId: '1',
      packageId: 1,
      itemKey: 'abcdefghij',
      label: 'Wall-1',
      filePath: path,
      sha256: 'abc',
      capturedAt: DateTime(2026),
      createdAt: DateTime(2026),
      previewPath: preview,
    );
    remote.answers = [
      {'token': 'a', 'status': 'studio_approved'},
    ];

    await runner.drainAll();

    expect(File(path).existsSync(), isFalse);
    expect(File(preview).existsSync(), isTrue);
  });

  test('a width the studio is holding goes on being asked about, and one it took stops', () async {
    final record = queuedWidth('w');
    remote.answers = [
      {'token': 'w', 'status': 'held'},
    ];
    await runner.drainAll();
    expect(record.serverStatus, 'held');

    remote.answers = [
      {'token': 'w', 'status': 'pushed'},
    ];
    await runner.refreshResults();
    expect(record.serverStatus, 'pushed');

    remote.answers = [
      {'token': 'w', 'status': 'held'},
    ];
    await runner.refreshResults();
    expect(record.serverStatus, 'pushed');
  });

  test('every open screen hears about a change', () async {
    var first = 0;
    var second = 0;
    void listenFirst() => first++;
    void listenSecond() => second++;
    runner.changes.addListener(listenFirst);
    runner.changes.addListener(listenSecond);
    queued('a');

    await runner.drainAll();

    expect(first, greaterThan(0));
    expect(second, first);
    runner.changes.removeListener(listenFirst);
    runner.changes.removeListener(listenSecond);
  });

  test('a results call that fails loses nothing and is asked again', () async {
    final record = queued('a')
      ..status = FollowUpUploadRecord.statusSent
      ..serverStatus = 'checking';
    final failing = _FailingResultsRemote();
    final failingRunner = FollowUpUploadRunner(
      local: local,
      remote: failing,
      resolveFile: (path) async => File(path),
    );

    await failingRunner.refreshResults();

    expect(record.serverStatus, 'checking');
    expect(File(record.filePath).existsSync(), isTrue);
  });

  group('a grid', () {
    late FollowUpUploadRunner gridRunner;

    setUp(() {
      gridRunner = FollowUpUploadRunner(
        local: local,
        remote: remote,
        resolveFile: (path) async => await File(path).exists() ? File(path) : null,
        stitchedPreviewPath: (record) async =>
            p.join(folder.path, '${record.token}${FollowUpUploadRecord.stitchedPreviewSuffix}'),
      );
    });

    test('is announced, then sent one photograph at a time, each deleted once it lands', () async {
      final grid = queuedGrid('g');
      final paths = grid.tiles.map((tile) => tile.path).toList();

      await gridRunner.drainAll();

      expect(remote.gridsRegistered, ['g']);
      expect(remote.tilesSent, ['r0c0', 'r0c1', 'r0c2']);
      expect(grid.status, FollowUpUploadRecord.statusSent);
      expect(grid.tiles.every((tile) => tile.sent), isTrue);
      expect(paths.any((path) => File(path).existsSync()), isFalse);
    });

    test('a dropped connection costs only what had not landed, and resumes there', () async {
      final grid = queuedGrid('g');
      remote
        ..tileFailure = const AppException(NetworkFailure())
        ..tilesBeforeFailure = 1;

      await gridRunner.drainAll();

      expect(grid.status, FollowUpUploadRecord.statusQueued);
      expect(grid.tiles.map((tile) => tile.sent), [true, false, false]);
      expect(File(grid.tiles[0].path).existsSync(), isFalse);
      expect(File(grid.tiles[1].path).existsSync(), isTrue);

      remote.tileFailure = null;
      await gridRunner.drainAll();

      expect(remote.tilesSent, ['r0c0', 'r0c1', 'r0c2']);
      expect(remote.gridsRegistered, ['g', 'g'], reason: 'announcing again is answered from the first');
      expect(grid.status, FollowUpUploadRecord.statusSent);
    });

    test('a photograph that arrived damaged is sent again, and nothing else is', () async {
      final grid = queuedGrid('g');
      remote
        ..tileFailure = const AppException(ServerFailure(400, 'The file arrived different.'))
        ..tilesBeforeFailure = 2;

      await gridRunner.drainAll();
      expect(grid.status, FollowUpUploadRecord.statusQueued);

      remote.tileFailure = null;
      await gridRunner.drainAll();

      expect(remote.tilesSent, ['r0c0', 'r0c1', 'r0c2']);
    });

    test('a refused one stops and says why', () async {
      final grid = queuedGrid('g');
      remote.failures['g'] = const AppException(ServerFailure(409, 'This wall is archived.'));

      await gridRunner.drainAll();

      expect(grid.status, FollowUpUploadRecord.statusFailed);
      expect(grid.lastError, 'This wall is archived.');
      expect(remote.tilesSent, isEmpty);
    });

    test('with an unsent photograph gone from the phone, it asks for a retake', () async {
      final grid = queuedGrid('g');
      File(grid.tiles[1].path).deleteSync();

      await gridRunner.drainAll();

      expect(grid.status, FollowUpUploadRecord.statusFailed);
      expect(remote.gridsRegistered, isEmpty);
    });

    test('goes on being asked about while stitching and while waiting for a choice', () async {
      final grid = queuedGrid('g');
      await gridRunner.drainAll();

      for (final status in ['stitching', 'needs_decision']) {
        remote.answers = [
          {'token': 'g', 'status': status, 'failed_cells': const []},
        ];
        await gridRunner.refreshResults();
        expect(grid.serverStatus, status);
      }

      remote.answers = [
        {'token': 'g', 'status': 'stitch_failed', 'reject_reason': 'Retake them.'},
      ];
      await gridRunner.refreshResults();
      expect(grid.rejectReason, 'Retake them.');

      remote.answers = [
        {'token': 'g', 'status': 'needs_decision'},
      ];
      await gridRunner.refreshResults();
      expect(grid.serverStatus, 'stitch_failed', reason: 'that was final');
    });

    test('remembers which cells did not join', () async {
      final grid = queuedGrid('g');
      await gridRunner.drainAll();

      remote.answers = [
        {
          'token': 'g',
          'status': 'needs_decision',
          'failed_cells': [
            {'row': 0, 'col': 2, 'reason': 'too few matches'},
          ],
        },
      ];
      await gridRunner.refreshResults();

      expect(grid.failedCells.single, (row: 0, col: 2));
    });

    test('the partial picture replaces the montage, once', () async {
      final grid = queuedGrid('g');
      final montage = p.join(folder.path, 'g.jpg');
      File(montage).writeAsStringSync('montage');
      grid.previewPath = montage;
      await gridRunner.drainAll();

      remote.answers = [
        {'token': 'g', 'status': 'needs_decision', 'failed_cells': const []},
      ];
      await gridRunner.refreshResults();
      await gridRunner.refreshResults();

      expect(grid.hasStitchedPreview, isTrue);
      expect(File(grid.previewPath!).readAsStringSync(), 'stitched');
      expect(File(montage).existsSync(), isFalse);
      expect(remote.previewsAsked, ['g']);
    });

    test('no picture is asked for before there is one', () async {
      queuedGrid('g');
      await gridRunner.drainAll();

      for (final status in ['stitching', 'stitch_failed']) {
        remote.answers = [
          {'token': 'g', 'status': status},
        ];
        await gridRunner.refreshResults();
      }

      expect(remote.previewsAsked, isEmpty);
    });

    test('a picture that could not be fetched is tried again, even after it is final', () async {
      final grid = queuedGrid('g');
      await gridRunner.drainAll();
      remote.previewFailure = const AppException(NetworkFailure());

      remote.answers = [
        {'token': 'g', 'status': 'kept', 'grade': 'ok'},
      ];
      await gridRunner.refreshResults();
      expect(grid.hasStitchedPreview, isFalse);
      expect(grid.serverStatus, 'kept');

      remote.previewFailure = null;
      await gridRunner.refreshResults();
      expect(grid.hasStitchedPreview, isTrue);
    });

    test('a decision is applied from the answer', () async {
      final grid = queuedGrid('g');
      await gridRunner.drainAll();
      remote.decisionAnswer = {'token': 'g', 'status': 'declined'};

      await gridRunner.decideGrid(grid, use: false);

      expect(remote.decisions, [false]);
      expect(grid.serverStatus, 'declined');
    });

    test('a decision with no connection says so and changes nothing', () async {
      final grid = queuedGrid('g')..serverStatus = 'needs_decision';
      remote.failures['g'] = const AppException(NetworkFailure());

      await expectLater(gridRunner.decideGrid(grid, use: true), throwsA(isA<AppException>()));

      expect(grid.serverStatus, 'needs_decision');
    });

    test('overtaken before all of it went, what is left here is removed', () async {
      final grid = queuedGrid('g');
      grid.status = FollowUpUploadRecord.statusSent;
      remote.answers = [
        {'token': 'g', 'status': 'superseded'},
      ];

      await gridRunner.refreshResults();

      expect(grid.tiles.any((tile) => File(tile.path).existsSync()), isFalse);
    });
  });
}

class _FailingResultsRemote extends _FakeRemote {
  @override
  Future<List<Map<String, dynamic>>> results(List<String> tokens) async =>
      throw const AppException(NetworkFailure());
}
