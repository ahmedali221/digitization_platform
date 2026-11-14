import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../sync_queue/domain/services/capture_uploader.dart';
import '../datasources/object_capture_local_data_source.dart';
import '../datasources/object_capture_remote_data_source.dart';
import '../models/object_capture_record.dart';

/// Sends an object's side and free photographs, then asks the server to
/// confirm it holds every one of them.
class ObjectPhotosUploader implements CaptureUploader {
  ObjectPhotosUploader({
    required ObjectCaptureLocalDataSource local,
    required ObjectCaptureRemoteDataSource remote,
    required DirectoryManager directoryManager,
  }) : _local = local,
       _remote = remote,
       _directoryManager = directoryManager;

  final ObjectCaptureLocalDataSource _local;
  final ObjectCaptureRemoteDataSource _remote;
  final DirectoryManager _directoryManager;

  @override
  bool hasCapture(String localWallId) =>
      _local.get(localWallId)?.photos.isNotEmpty ?? false;

  @override
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  }) async {
    final record = _local.get(localWallId)!;
    final total = record.photos.length;

    for (var i = 0; i < total; i++) {
      final photo = record.photos[i];
      if (!photo.uploaded) {
        await _send(serverWallId, photo);
        // Stored photo by photo, so an upload cut off half-way resumes with
        // the photos still to go.
        record.photos[i] = photo.copyWith(uploaded: true);
        await _local.put(record);
      }
      onProgress((i + 1) / total);
    }

    await _remote.complete(
      wallId: serverWallId,
      checksums: [for (final photo in record.photos) photo.sha256],
    );
  }

  Future<void> _send(String serverWallId, ObjectPhotoRecord photo) async {
    final image =
        await _directoryManager.resolveExistingFile(photo.file) ??
        File(photo.file);
    await _remote.uploadPhoto(
      wallId: serverWallId,
      openImageBytes: image.openRead,
      imageLength: await image.length(),
      fileName: p.basename(image.path),
      sha256: photo.sha256,
      capturedAt: photo.capturedAt,
      side: photo.side,
      comment: photo.comment,
    );
  }

  @override
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  }) => _directoryManager.deleteBackup(localWallId);
}
