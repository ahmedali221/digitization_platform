import 'dart:io';

import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:digitization_platform/features/grid_capture/data/datasources/grid_capture_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _TestDirectoryManager extends DirectoryManager {
  _TestDirectoryManager(this.root);

  final Directory root;

  @override
  Future<Directory> sessionDir(String sessionId) =>
      _directory('sessions', sessionId);

  @override
  Future<Directory> backupDir(String sessionId) =>
      _directory('backup', sessionId);

  Future<Directory> _directory(String kind, String sessionId) async {
    final directory = Directory(p.join(root.path, kind, sessionId));
    await directory.create(recursive: true);
    return directory;
  }
}

void main() {
  late Directory root;
  late GridCaptureLocalDataSource dataSource;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('wallbase-delete-shot-');
    dataSource = GridCaptureLocalDataSource(
      directoryManager: _TestDirectoryManager(root),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('deletes the selected session photo and its backup copy', () async {
    final sessionDirectory = Directory(p.join(root.path, 'sessions', 'wall-1'));
    final backupDirectory = Directory(p.join(root.path, 'backup', 'wall-1'));
    await sessionDirectory.create(recursive: true);
    await backupDirectory.create(recursive: true);

    final sessionPhoto = File(p.join(sessionDirectory.path, 'R1C1_S1.jpg'));
    final backupPhoto = File(p.join(backupDirectory.path, 'R1C1_S1.jpg'));
    final otherPhoto = File(p.join(sessionDirectory.path, 'R1C1_S2.jpg'));
    await sessionPhoto.writeAsBytes([1]);
    await backupPhoto.writeAsBytes([1]);
    await otherPhoto.writeAsBytes([2]);

    await dataSource.deleteShot(wallId: 'wall-1', filePath: sessionPhoto.path);

    expect(await sessionPhoto.exists(), isFalse);
    expect(await backupPhoto.exists(), isFalse);
    expect(await otherPhoto.exists(), isTrue);
  });
}
