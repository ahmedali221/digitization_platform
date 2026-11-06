import 'dart:io';

import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_local_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_remote_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/data/repositories/follow_up_repository_impl.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
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
  targets: [],
  files: {},
);

const _annotation = FollowUpAnnotation(
  id: 41,
  referenceCode: 'W-1',
  wall: FollowUpWall(id: 1, name: 'North Wall'),
  grade: 'weak',
  reasons: [],
  picture: null,
  polygon: [],
  closeupKey: null,
);

class _FakeLocal implements FollowUpLocalDataSource {
  final Map<String, FollowUpUploadRecord> records = {};

  /// What was already queued each time a record was added.
  final List<List<String>> tokensBeforeEachPut = [];
  bool failPuts = false;

  @override
  List<FollowUpUploadRecord> all() => records.values.toList();

  @override
  Future<void> put(FollowUpUploadRecord record) async {
    if (failPuts) throw StateError('box is closed');
    tokensBeforeEachPut.add(records.keys.toList());
    records[record.token] = record;
  }

  @override
  Future<void> delete(String token) async => records.remove(token);
}

class _FakeDirectories implements DirectoryManager {
  _FakeDirectories(this.root);

  final Directory root;

  @override
  Future<Directory> followUpDir(String siteId, [String? child]) =>
      Directory(p.joinAll([root.path, 'follow_up', siteId, ?child])).create(recursive: true);

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
    root = Directory.systemTemp.createTempSync('follow_up_repository_');
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

  /// A single photograph of the same annotation, still waiting to be sent.
  FollowUpUploadRecord queueOlderPhotograph() {
    final record = FollowUpUploadRecord(
      token: 'older',
      kind: FollowUpUploadRecord.kindAnnotation,
      siteId: _package.siteId,
      packageId: _package.id,
      itemKey: _annotation.id.toString(),
      label: _annotation.referenceCode,
      filePath: shot('older.jpg'),
      sha256: 'abc',
      capturedAt: DateTime(2026),
      createdAt: DateTime(2026),
    );
    local.records[record.token] = record;
    return record;
  }

  Future<void> queue(Map<int, String> photos) => repository.queueAnnotationGrid(
    package: _package,
    annotation: _annotation,
    rows: 1,
    cols: photos.length,
    photos: photos,
  );

  List<String> copiesOnDisk() {
    final captures = Directory(p.join(root.path, 'follow_up', _package.siteId, 'captures'));
    if (!captures.existsSync()) return const [];
    return captures.listSync().map((entry) => p.basename(entry.path)).toList();
  }

  group('when the grid is saved', () {
    test('queues a copy of every photograph and tries to send it', () async {
      await queue({0: shot('a.jpg'), 1: shot('b.jpg')});

      final record = local.records.values.single;
      expect(record.kind, FollowUpUploadRecord.kindAnnotationGrid);
      expect(record.tiles.map((tile) => (tile.row, tile.col)), [(0, 0), (0, 1)]);
      expect(record.tiles.every((tile) => File(tile.path).existsSync()), isTrue);
      expect(copiesOnDisk(), hasLength(2));
      expect(runner.drains, 1);
    });

    test('replaces the older photograph, which is never queued alongside it', () async {
      final older = queueOlderPhotograph();

      await queue({0: shot('a.jpg'), 1: shot('b.jpg')});

      expect(local.records.containsKey(older.token), isFalse);
      expect(File(older.filePath).existsSync(), isFalse);
      expect(local.tokensBeforeEachPut.single, isEmpty);
    });
  });

  group('when a photograph can not be copied', () {
    test('throws, and queues nothing', () async {
      await expectLater(
        queue({0: shot('a.jpg'), 1: p.join(root.path, 'missing.jpg')}),
        throwsA(isA<FileSystemException>()),
      );

      expect(local.records, isEmpty);
      expect(runner.drains, 0);
    });

    test('keeps the older photograph waiting', () async {
      final older = queueOlderPhotograph();

      await expectLater(queue({0: p.join(root.path, 'missing.jpg')}), throwsA(isA<FileSystemException>()));

      expect(local.records.keys, [older.token]);
      expect(File(older.filePath).existsSync(), isTrue);
    });

    test('leaves the originals, and no partial copies, so it can be tried again', () async {
      final original = shot('a.jpg');

      await expectLater(
        queue({0: original, 1: p.join(root.path, 'missing.jpg')}),
        throwsA(isA<FileSystemException>()),
      );

      expect(File(original).existsSync(), isTrue);
      expect(copiesOnDisk(), isEmpty);

      await queue({0: original, 1: shot('b.jpg')});
      expect(local.records, hasLength(1));
      expect(copiesOnDisk(), hasLength(2));
    });
  });

  test('a record that can not be written leaves no copies behind either', () async {
    local.failPuts = true;
    final original = shot('a.jpg');

    await expectLater(queue({0: original, 1: shot('b.jpg')}), throwsA(isA<StateError>()));

    expect(File(original).existsSync(), isTrue);
    expect(copiesOnDisk(), isEmpty);
  });

  group('a folder of shots', () {
    test('is deleted with everything in it', () async {
      final folder = await repository.newShotsFolder(_package.siteId);
      File(p.join(folder, 'shot.jpg')).writeAsStringSync('jpeg');

      await repository.deleteShotsFolder(folder);

      expect(Directory(folder).existsSync(), isFalse);
    });

    test('that has already gone is no trouble', () async {
      final folder = await repository.newShotsFolder(_package.siteId);
      await repository.deleteShotsFolder(folder);

      await expectLater(repository.deleteShotsFolder(folder), completes);
    });
  });

  group('a single photograph', () {
    Future<void> queuePhotograph(String path) => repository.queueAnnotationCapture(
      package: _package,
      annotation: _annotation,
      photoPath: path,
    );

    test('is queued as a copy, and tried straight away', () async {
      final original = shot('a.jpg');

      await queuePhotograph(original);

      final record = local.records.values.single;
      expect(record.kind, FollowUpUploadRecord.kindAnnotation);
      expect(File(record.filePath).existsSync(), isTrue);
      expect(record.sha256, isNotEmpty);
      expect(File(original).existsSync(), isTrue);
      expect(runner.drains, 1);
    });

    test('replaces the older one, which is never queued alongside it', () async {
      final older = queueOlderPhotograph();

      await queuePhotograph(shot('a.jpg'));

      expect(local.records.containsKey(older.token), isFalse);
      expect(File(older.filePath).existsSync(), isFalse);
      expect(local.tokensBeforeEachPut.single, isEmpty);
    });

    test('that can not be copied keeps the older one waiting', () async {
      final older = queueOlderPhotograph();

      await expectLater(queuePhotograph(p.join(root.path, 'missing.jpg')), throwsA(isA<FileSystemException>()));

      expect(local.records.keys, [older.token]);
      expect(File(older.filePath).existsSync(), isTrue);
      expect(runner.drains, 0);
    });

    test('whose record can not be written leaves the original and no copy, to try again', () async {
      local.failPuts = true;
      final original = shot('a.jpg');

      await expectLater(queuePhotograph(original), throwsA(isA<StateError>()));

      expect(File(original).existsSync(), isTrue);
      expect(copiesOnDisk(), isEmpty);

      local.failPuts = false;
      await queuePhotograph(original);

      expect(local.records, hasLength(1));
      expect(copiesOnDisk(), hasLength(1));
    });
  });
}
