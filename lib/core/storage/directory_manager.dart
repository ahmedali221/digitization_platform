import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Creates/validates the on-device directory layout from
/// FLUTTER_MOBILE_PLAN.md §3:
///   app_documents/packages/{site_id}/   downloaded site+floor JSON, images
///   app_documents/sessions/{session_id}/  in-progress/completed capture shots
///   app_documents/backup/{session_id}/    write-once raw-photo copies
///   app_documents/thumbs/                 status-index thumbnails
///
/// Also wraps `disk_space_plus` as the storage-watchdog primitive (Phase 7):
/// callers decide the threshold, this just reports free space honestly.
class DirectoryManager {
  DirectoryManager({DiskSpacePlus? diskSpace})
    : _diskSpace = diskSpace ?? DiskSpacePlus();

  final DiskSpacePlus _diskSpace;
  Directory? _docsDir;

  /// Resolves and caches the app documents directory once. Callers that only
  /// ever await a directory method don't need this — but `MapGeometryMapper`
  /// mirrors `SiteRepository`'s synchronous find*() methods, so it needs the
  /// docs path already resolved before it can build an image path without an
  /// `await`. Called once at boot, before the first frame (see `main.dart`).
  Future<void> init() async {
    _docsDir ??= await getApplicationDocumentsDirectory();
  }

  Future<Directory> packageDir(String siteId) => _ensure(['packages', siteId]);

  Future<Directory> sessionDir(String sessionId) =>
      _ensure(['sessions', sessionId]);

  Future<Directory> backupDir(String sessionId) =>
      _ensure(['backup', sessionId]);

  Future<Directory> thumbsDir() => _ensure(['thumbs']);

  /// Deletes a session's backup copies. Callers must only invoke this after
  /// the corresponding sync session has been confirmed by the server
  /// (Invariant 1) — this method itself has no opinion on when that is.
  Future<void> deleteBackup(String sessionId) async {
    final dir = Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'backup',
        sessionId,
      ),
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> deletePackage(String siteId) async {
    final dir = Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'packages',
        siteId,
      ),
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<int> freeSpaceBytes() async {
    final freeMb = await _diskSpace.getFreeDiskSpace ?? 0;
    return (freeMb * 1024 * 1024).round();
  }

  Future<bool> hasSufficientSpace(int estimatedBytes) async =>
      await freeSpaceBytes() >= estimatedBytes;

  /// Synchronous counterpart to [packageDir], for an already-downloaded
  /// site's background image. Returns null before [init] has resolved, or if
  /// [fileName] isn't actually present under `packages/{siteId}/images/` —
  /// callers treat either case as "no background image available".
  String? packageImagePathSync(String siteId, String fileName) {
    final docsDir = _docsDir;
    if (docsDir == null) return null;
    final path = p.join(docsDir.path, 'packages', siteId, 'images', fileName);
    return File(path).existsSync() ? path : null;
  }

  Future<Directory> _ensure(List<String> segments) async {
    final docsDir = _docsDir ??= await getApplicationDocumentsDirectory();
    final dir = Directory(p.joinAll([docsDir.path, ...segments]));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
