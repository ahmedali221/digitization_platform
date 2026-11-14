import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../models/object_scan_record.dart';

/// The `object_scans` box and the photograph files behind it.
///
/// A scan's photographs live in `sessions/{wallId}/scan/`, beside the
/// object's other photographs but apart from them. They get no second copy
/// in `backup/`, unlike those: a scan is dozens of full-size photographs,
/// and its one copy is kept until the server confirms it holds them all.
class ObjectScanLocalDataSource {
  ObjectScanLocalDataSource({required DirectoryManager directoryManager})
    : _directoryManager = directoryManager;

  static const _scanFolderName = 'scan';
  static const _incomingFolderName = 'scan_incoming';
  static const _previewFolderName = 'scan_preview';

  final DirectoryManager _directoryManager;

  Box<ObjectScanRecord> get _box =>
      Hive.box<ObjectScanRecord>(HiveBoxes.objectScans);

  ObjectScanRecord? get(String wallId) => _box.get(wallId);

  Future<void> put(ObjectScanRecord record) => _box.put(record.wallId, record);

  Stream<void> watch(String wallId) => _box.watch(key: wallId);

  /// Where the camera writes a shot before it is kept.
  Future<Directory> incomingDir(String wallId) =>
      _folder(wallId, _incomingFolderName);

  /// Moves the shot at [sourcePath] into the scan as [fileName] and returns
  /// where it landed with its checksum.
  Future<({String path, String sha256})> keepShot({
    required String wallId,
    required String fileName,
    required String sourcePath,
  }) async {
    final scanDir = await _folder(wallId, _scanFolderName);
    final kept = await File(sourcePath).rename(p.join(scanDir.path, fileName));
    final digest = await sha256.bind(kept.openRead()).first;
    return (path: kept.path, sha256: digest.toString());
  }

  /// Where the rough model with the server id [previewId] is saved. The
  /// folder is emptied first: a scan has one rough model, the latest.
  Future<String> newPreviewFile(String wallId, int previewId) async {
    final folder = await _folder(wallId, _previewFolderName);
    await for (final old in folder.list()) {
      await old.delete(recursive: true);
    }
    return p.join(folder.path, 'preview_$previewId.glb');
  }

  Future<void> deleteFile(String filePath) async {
    final file =
        await _directoryManager.resolveExistingFile(filePath) ?? File(filePath);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _folder(String wallId, String name) async {
    final sessionDir = await _directoryManager.sessionDir(wallId);
    final folder = Directory(p.join(sessionDir.path, name));
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }
}
