import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/gallery_backup_service.dart';
import '../../../sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../data/datasources/capture_session_local_data_source.dart';
import '../../data/models/capture_session_record.dart';

/// Rebuilds local capture sessions from their gallery-backed copies after
/// something wiped the `sessions` Hive box — the recovery counterpart to
/// [GalleryBackupService], which every captured photo is also saved
/// through. See [GalleryBackupService]'s doc comment for why this exists
/// (an iOS reinstall wipes Documents/Hive but not the device's own Photos
/// library).
///
/// A wall only counts as orphaned (recoverable) if there is *no* local
/// session record for it at all — if one already exists, its state is
/// authoritative and this leaves it alone. Confirmed-and-synced walls never
/// reach here, since [GalleryBackupService]'s copies for a wall are deleted
/// once its session is confirmed server-side (see `SyncQueueRunner`).
class CaptureRecoveryService {
  CaptureRecoveryService({
    required GalleryBackupService galleryBackup,
    required CaptureSessionLocalDataSource sessionLocal,
    required DirectoryManager directoryManager,
    required SyncEnqueuer syncEnqueuer,
  }) : _galleryBackup = galleryBackup,
       _sessionLocal = sessionLocal,
       _directoryManager = directoryManager,
       _syncEnqueuer = syncEnqueuer;

  final GalleryBackupService _galleryBackup;
  final CaptureSessionLocalDataSource _sessionLocal;
  final DirectoryManager _directoryManager;
  final SyncEnqueuer _syncEnqueuer;

  /// Scans the gallery and recovers every orphaned wall it finds. Returns
  /// the number of walls recovered — always safe to call, including when
  /// nothing is orphaned (the common case), since it's a no-op then.
  Future<int> recoverOrphanedWalls() async {
    final entries = await _galleryBackup.scanBackups();
    if (entries.isEmpty) return 0;

    final byWall = <String, List<GalleryBackupEntry>>{};
    for (final entry in entries) {
      byWall.putIfAbsent(entry.info.wallId, () => []).add(entry);
    }

    var recovered = 0;
    for (final MapEntry(key: wallId, value: photos) in byWall.entries) {
      if (_sessionLocal.get(wallId) != null) continue; // not orphaned
      if (await _recoverWall(wallId, photos)) recovered++;
    }
    return recovered;
  }

  Future<bool> _recoverWall(
    String wallId,
    List<GalleryBackupEntry> photos,
  ) async {
    try {
      final siteId = photos.first.info.siteId;
      final maxRow = photos
          .map((e) => e.info.row)
          .reduce((a, b) => a > b ? a : b);
      final maxCol = photos
          .map((e) => e.info.col)
          .reduce((a, b) => a > b ? a : b);

      final byCell = <(int, int), List<GalleryBackupEntry>>{};
      for (final photo in photos) {
        byCell.putIfAbsent((photo.info.row, photo.info.col), () => []).add(photo);
      }

      final sessionDir = await _directoryManager.sessionDir(wallId);
      final cells = <CaptureCellRecord>[];
      for (var row = 0; row <= maxRow; row++) {
        for (var col = 0; col <= maxCol; col++) {
          final photoRecords = <CapturePhotoRecord>[];
          for (final photo in byCell[(row, col)] ?? const <GalleryBackupEntry>[]) {
            final bytes = await photo.asset.originBytes;
            if (bytes == null) continue;
            final targetPath = p.join(
              sessionDir.path,
              'R${row}C${col}_S${photo.info.shot}.jpg',
            );
            await File(targetPath).writeAsBytes(bytes);
            photoRecords.add(
              CapturePhotoRecord(
                file: targetPath,
                sha256: sha256.convert(bytes).toString(),
                shot: photo.info.shot,
                capturedAt: photo.asset.createDateTime,
              ),
            );
          }
          cells.add(
            CaptureCellRecord(row: row, col: col, photos: photoRecords),
          );
        }
      }
      if (cells.every((c) => c.photos.isEmpty)) return false;

      await _sessionLocal.put(
        CaptureSessionRecord(
          sessionId: wallId,
          wallId: wallId,
          // Not recoverable from the gallery backup alone, and purely local
          // bookkeeping (map navigation UI) — never sent to the server (see
          // SyncRemoteDataSource.registerSession) — so leaving it empty
          // doesn't block re-syncing the recovered photos.
          floorId: '',
          siteId: siteId,
          gridRows: maxRow + 1,
          gridCols: maxCol + 1,
          cells: cells,
          state: 'completed',
          createdAt: DateTime.now(),
          completedAt: DateTime.now(),
        ),
      );
      await _syncEnqueuer.enqueueSession(
        wallId: wallId,
        siteId: siteId,
        displayName: wallId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
