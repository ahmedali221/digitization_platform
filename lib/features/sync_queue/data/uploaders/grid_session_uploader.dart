import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/storage/device_id_provider.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/gallery_backup_service.dart';
import '../../../grid_capture/data/datasources/capture_session_local_data_source.dart';
import '../../domain/services/capture_uploader.dart';
import '../datasources/sync_remote_data_source.dart';

/// Sends a wall's or painting's grid: register the grid and its checksum
/// manifest, upload every cell photo, confirm.
class GridSessionUploader implements CaptureUploader {
  GridSessionUploader({
    required CaptureSessionLocalDataSource sessionLocal,
    required SyncRemoteDataSource remote,
    required DeviceIdProvider deviceIdProvider,
    required DirectoryManager directoryManager,
    required GalleryBackupService galleryBackup,
  }) : _sessionLocal = sessionLocal,
       _remote = remote,
       _deviceIdProvider = deviceIdProvider,
       _directoryManager = directoryManager,
       _galleryBackup = galleryBackup;

  /// Registering the session is the first fifth of the bar; the photos are
  /// the rest.
  static const _registeredFraction = 0.2;

  final CaptureSessionLocalDataSource _sessionLocal;
  final SyncRemoteDataSource _remote;
  final DeviceIdProvider _deviceIdProvider;
  final DirectoryManager _directoryManager;
  final GalleryBackupService _galleryBackup;

  @override
  bool hasCapture(String localWallId) => _sessionLocal.get(localWallId) != null;

  @override
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  }) async {
    final session = _sessionLocal.get(localWallId)!;
    final deviceId = await _deviceIdProvider.getOrCreateDeviceId();

    final serverSessionId = await _remote.registerSession(
      deviceId: deviceId,
      siteId: siteId,
      wallId: serverWallId,
      session: session,
    );
    session.serverSessionId = serverSessionId;
    await _sessionLocal.put(session);
    onProgress(_registeredFraction);

    final photos = [
      for (final cell in session.cells)
        for (final photo in cell.photos) (cell: cell, photo: photo),
    ];
    for (var i = 0; i < photos.length; i++) {
      final entry = photos[i];
      final image =
          await _directoryManager.resolveExistingFile(entry.photo.file) ??
          File(entry.photo.file);
      await _remote.uploadCellPhoto(
        wallId: serverWallId,
        row: entry.cell.row,
        col: entry.cell.col,
        shot: entry.photo.shot,
        openImageBytes: image.openRead,
        imageLength: await image.length(),
        fileName: p.basename(image.path),
      );
      onProgress(
        _registeredFraction +
            (1 - _registeredFraction) * ((i + 1) / photos.length),
      );
    }

    await _remote.confirmSession(serverSessionId);
  }

  @override
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  }) async {
    await _directoryManager.deleteBackup(localWallId);
    // Best-effort — see GalleryBackupService's doc comment for why this
    // has to happen on every confirm, not just be left for later cleanup.
    await _galleryBackup.deleteWallBackup(siteId: siteId, wallId: localWallId);
  }
}
