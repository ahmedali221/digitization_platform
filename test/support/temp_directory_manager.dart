import 'dart:io';

import 'package:digitization_platform/core/storage/directory_manager.dart';
import 'package:path/path.dart' as p;

/// A [DirectoryManager] rooted in a throwaway folder, so capture code can
/// write real photo files in a test without the platform's documents path.
class TempDirectoryManager extends DirectoryManager {
  TempDirectoryManager(this.root);

  static Future<TempDirectoryManager> create() async => TempDirectoryManager(
    await Directory.systemTemp.createTemp('wallbase-test-files-'),
  );

  final Directory root;

  @override
  Future<Directory> sessionDir(String sessionId) =>
      Directory(p.join(root.path, 'sessions', sessionId)).create(recursive: true);

  @override
  Future<Directory> backupDir(String sessionId) =>
      Directory(p.join(root.path, 'backup', sessionId)).create(recursive: true);

  @override
  Future<void> deleteBackup(String sessionId) async {
    final backup = Directory(p.join(root.path, 'backup', sessionId));
    if (await backup.exists()) await backup.delete(recursive: true);
  }

  @override
  Future<File?> resolveExistingFile(String storedPath) async {
    final file = File(storedPath);
    return await file.exists() ? file : null;
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
