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
}

class _FailingResultsRemote extends _FakeRemote {
  @override
  Future<List<Map<String, dynamic>>> results(List<String> tokens) async =>
      throw const AppException(NetworkFailure());
}
