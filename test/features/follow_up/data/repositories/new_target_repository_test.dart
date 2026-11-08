import 'dart:io';

import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_local_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_remote_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/data/repositories/follow_up_repository_impl.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/new_target_details.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/target_width.dart';
import 'package:digitization_platform/features/follow_up/domain/services/follow_up_upload_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _package = FollowUpPackage(
  id: 7,
  siteId: '1',
  siteName: 'Karnak',
  createdAt: null,
  totalBytes: 0,
  annotations: [],
  targets: [
    FollowUpTarget(
      arKey: 'abcdefghij',
      label: 'Karnak — Wall-1',
      description: null,
      wall: null,
      wallLabel: 'Wall-1',
      imageKey: 'target_abcdefghij',
      videoFrameKey: null,
      hasVideo: false,
    ),
  ],
  files: {},
);

const _details = NewTargetDetails(code: '  W-12-A ', description: ' A procession of offering bearers. ');

class _FakeLocal implements FollowUpLocalDataSource {
  final Map<String, FollowUpUploadRecord> records = {};

  @override
  List<FollowUpUploadRecord> all() => records.values.toList();

  @override
  Future<void> put(FollowUpUploadRecord record) async => records[record.token] = record;

  @override
  Future<void> delete(String token) async => records.remove(token);
}

class _FakeDirectories implements DirectoryManager {
  _FakeDirectories(this.root);

  final Directory root;

  @override
  Future<Directory> followUpDir(String siteId, [String? child]) {
    final parts = [root.path, 'follow_up', siteId];
    if (child != null) parts.add(child);
    return Directory(p.joinAll(parts)).create(recursive: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRunner implements FollowUpUploadRunner {
  int drains = 0;

  @override
  Future<void> drainAll() async => drains++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedRemote implements FollowUpRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory root;
  late _FakeLocal local;
  late _FakeRunner runner;
  late FollowUpRepositoryImpl repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('new_target_repository_');
    local = _FakeLocal();
    runner = _FakeRunner();
    repository = FollowUpRepositoryImpl(
      local: local,
      remote: _UnusedRemote(),
      directoryManager: _FakeDirectories(root),
      runner: runner,
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  String shot(String name) {
    final path = p.join(root.path, name);
    File(path).writeAsStringSync('jpeg');
    return path;
  }

  Future<void> queue({NewTargetDetails details = _details}) => repository.queueNewTarget(
    package: _package,
    details: details,
    photoPath: shot('chosen.jpg'),
    width: const TargetWidth(1.4254, TargetWidth.sourceAr),
  );

  FollowUpUploadRecord onlyRecord() => local.records.values.single;

  test('a new target is kept with its trimmed code and description, and sending starts', () async {
    await queue();

    final record = onlyRecord();
    expect(record.kind, FollowUpUploadRecord.kindNewTarget);
    expect(record.itemKey, 'W-12-A');
    expect(record.label, 'W-12-A');
    expect(record.description, 'A procession of offering bearers.');
    expect(record.physicalWidthM, 1.425);
    expect(record.widthSource, TargetWidth.sourceAr);
    expect(record.packageId, _package.id);
    expect(record.status, FollowUpUploadRecord.statusQueued);
    expect(File(record.filePath).existsSync(), isTrue);
    expect(record.sha256, hasLength(64));
    expect(runner.drains, 1);
    expect(repository.newTargets(_package.siteId), [record]);
  });

  group('codeConflict', () {
    test('an empty code and a free one have none', () {
      expect(repository.codeConflict(_package, '   '), isNull);
      expect(repository.codeConflict(_package, 'W-99'), isNull);
    });

    test("a package target's studio label is taken whatever the case or spaces", () {
      expect(repository.codeConflict(_package, ' wall-1 '), isNotNull);
    });

    test('a new target on its way holds its code, one sent and created too', () async {
      await queue();
      expect(repository.codeConflict(_package, 'w-12-a'), isNotNull);

      onlyRecord()
        ..status = FollowUpUploadRecord.statusSent
        ..serverStatus = 'created';
      expect(repository.codeConflict(_package, 'W-12-A'), isNotNull);
    });

    test('one not sent, or rejected on the dashboard, leaves its code free', () async {
      await queue();
      onlyRecord().status = FollowUpUploadRecord.statusFailed;
      expect(repository.codeConflict(_package, 'W-12-A'), isNull);

      onlyRecord()
        ..status = FollowUpUploadRecord.statusSent
        ..serverStatus = 'rejected';
      expect(repository.codeConflict(_package, 'W-12-A'), isNull);
    });

    test("another site's new targets don't count", () async {
      await queue();
      const elsewhere = FollowUpPackage(
        id: 8,
        siteId: '2',
        siteName: 'Luxor',
        createdAt: null,
        totalBytes: 0,
        annotations: [],
        targets: [],
        files: {},
      );

      expect(repository.codeConflict(elsewhere, 'W-12-A'), isNull);
    });
  });

  test('adding it again under the code of one not sent takes its place', () async {
    await queue();
    final failed = onlyRecord()..status = FollowUpUploadRecord.statusFailed;

    await queue();

    expect(local.records.containsKey(failed.token), isFalse);
    expect(File(failed.filePath).existsSync(), isFalse);
    expect(local.records, hasLength(1));
  });

  test('if it cannot be kept, nothing is left behind and the photograph is untouched', () async {
    final photo = shot('chosen.jpg');
    final failing = FollowUpRepositoryImpl(
      local: _BrokenLocal(),
      remote: _UnusedRemote(),
      directoryManager: _FakeDirectories(root),
      runner: runner,
    );

    await expectLater(
      failing.queueNewTarget(
        package: _package,
        details: _details,
        photoPath: photo,
        width: const TargetWidth(1.4, TargetWidth.sourceManual),
      ),
      throwsStateError,
    );

    expect(File(photo).existsSync(), isTrue);
    final captures = Directory(p.join(root.path, 'follow_up', _package.siteId, 'captures'));
    expect(captures.listSync(), isEmpty);
    expect(runner.drains, 0);
  });
}

class _BrokenLocal extends _FakeLocal {
  @override
  Future<void> put(FollowUpUploadRecord record) async => throw StateError('box is closed');
}
