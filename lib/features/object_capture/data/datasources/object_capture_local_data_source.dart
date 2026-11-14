import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../models/object_capture_record.dart';

/// The `object_captures` box and the photo files behind it. A kept shot lives
/// in `sessions/{wallId}/` with a copy in `backup/{wallId}/` made at once
/// (Invariant 1 — the backup goes only after the server confirms), the same
/// layout grid capture uses, so one wall id still maps to one folder pair.
class ObjectCaptureLocalDataSource {
  ObjectCaptureLocalDataSource({required DirectoryManager directoryManager})
    : _directoryManager = directoryManager;

  static const _incomingFolderName = 'incoming';

  final DirectoryManager _directoryManager;

  Box<ObjectCaptureRecord> get _box =>
      Hive.box<ObjectCaptureRecord>(HiveBoxes.objectCaptures);

  ObjectCaptureRecord? get(String wallId) => _box.get(wallId);

  Future<void> put(ObjectCaptureRecord record) =>
      _box.put(record.wallId, record);

  Stream<void> watch(String wallId) => _box.watch(key: wallId);

  /// Where the camera writes shots that nothing has claimed yet.
  Future<Directory> incomingDir(String wallId) async {
    final sessionDir = await _directoryManager.sessionDir(wallId);
    final incoming = Directory(p.join(sessionDir.path, _incomingFolderName));
    if (!await incoming.exists()) await incoming.create(recursive: true);
    return incoming;
  }

  /// Every shot still waiting in [incomingDir], oldest first.
  Future<List<String>> strayShotPaths(String wallId) async {
    final incoming = await incomingDir(wallId);
    final files = await incoming.list().where((e) => e is File).toList();
    final paths = files.map((file) => file.path).toList()..sort();
    return paths;
  }

  /// Moves the shot at [sourcePath] into the capture under [fileStem],
  /// backs it up, and returns where it landed with its checksum. The stem
  /// carries a timestamp, so a retake never overwrites the photograph it
  /// replaces before that one is deliberately deleted.
  Future<({String path, String sha256})> keepShot({
    required String wallId,
    required String fileStem,
    required String sourcePath,
  }) async {
    final fileName = '$fileStem.jpg';
    final sessionDir = await _directoryManager.sessionDir(wallId);
    final kept = await File(
      sourcePath,
    ).rename(p.join(sessionDir.path, fileName));

    final backupDir = await _directoryManager.backupDir(wallId);
    await kept.copy(p.join(backupDir.path, fileName));

    final bytes = await kept.readAsBytes();
    return (path: kept.path, sha256: sha256.convert(bytes).toString());
  }

  Future<void> deleteShot({
    required String wallId,
    required String filePath,
  }) async {
    final sessionFile = File(filePath);
    if (await sessionFile.exists()) await sessionFile.delete();

    final backupDir = await _directoryManager.backupDir(wallId);
    final backupFile = File(p.join(backupDir.path, p.basename(filePath)));
    if (await backupFile.exists()) await backupFile.delete();
  }
}
