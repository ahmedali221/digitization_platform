import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';

/// File I/O for one wall's capture round: saves a just-shot photo into
/// `sessions/{wallId}/` (see CaptureSessionRecord's doc comment for why
/// this is keyed by wallId, not a minted session id), immediately copies it
/// to `backup/{wallId}/` (Invariant 1 — never delete until the server
/// confirms), and writes the atomic completion manifest. Pure file I/O — no
/// grid/wall state, which stays with [GridCaptureRepository].
class GridCaptureLocalDataSource {
  GridCaptureLocalDataSource({DirectoryManager? directoryManager})
    : _directoryManager = directoryManager ?? DirectoryManager();

  final DirectoryManager _directoryManager;

  /// Saves the shot, copies it to backup, and returns both the saved path
  /// and its sha256 — the caller (GridCaptureRepositoryImpl) records both
  /// against the session's manifest.
  Future<({String path, String sha256}) > saveShot({
    required String wallId,
    required int row,
    required int col,
    required int shotNumber,
    required XFile capturedFile,
  }) async {
    final sessionDir = await _directoryManager.sessionDir(wallId);
    final fileName = 'R${row}C${col}_S$shotNumber.jpg';
    final targetPath = p.join(sessionDir.path, fileName);
    await capturedFile.saveTo(targetPath);

    final backupDir = await _directoryManager.backupDir(wallId);
    await File(targetPath).copy(p.join(backupDir.path, fileName));

    final checksum = await _sha256Of(targetPath);
    return (path: targetPath, sha256: checksum);
  }

  /// Atomic write per the session-integrity rule: a session only "exists"
  /// (for interrupted-session detection) once this file is present.
  Future<void> writeManifest({
    required String wallId,
    required Map<String, dynamic> manifest,
  }) async {
    final sessionDir = await _directoryManager.sessionDir(wallId);
    final finalPath = p.join(sessionDir.path, 'MANIFEST.json');
    final tmpPath = '$finalPath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(jsonEncode(manifest));
    await tmpFile.rename(finalPath);
  }

  Future<String> _sha256Of(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
