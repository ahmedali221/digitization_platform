import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../sync_queue/domain/services/capture_uploader.dart';
import '../datasources/object_scan_local_data_source.dart';
import '../datasources/object_scan_remote_data_source.dart';
import '../mappers/object_scan_mapper.dart';
import '../models/object_scan_record.dart';

/// Sends a finished 3D scan: starts it on the server, uploads each
/// photograph, then asks the server to confirm it holds every one, which is
/// also what sends the scan to be checked.
class ObjectScanUploader implements CaptureUploader {
  ObjectScanUploader({
    required ObjectScanLocalDataSource local,
    required ObjectScanRemoteDataSource remote,
    required DirectoryManager directoryManager,
  }) : _local = local,
       _remote = remote,
       _directoryManager = directoryManager;

  final ObjectScanLocalDataSource _local;
  final ObjectScanRemoteDataSource _remote;
  final DirectoryManager _directoryManager;

  @override
  bool hasCapture(String localWallId) {
    final record = _local.get(localWallId);
    return record != null && record.isFinished && record.shots.isNotEmpty;
  }

  @override
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  }) async {
    final record = _local.get(localWallId)!;

    final started = await _remote.start(
      wallId: serverWallId,
      clientUuid: record.clientUuid,
      fullCircle: record.fullCircle,
    );
    record.serverScanId = started.id;
    await _local.put(record);

    final total = record.shots.length;
    for (var i = 0; i < total; i++) {
      final shot = record.shots[i];
      if (!shot.uploaded) {
        // Stored photograph by photograph, so an upload cut off half-way
        // resumes with those still to go.
        record.shots[i] = shot.asUploaded(await _send(started.id, shot));
        await _local.put(record);
      }
      onProgress((i + 1) / total);
    }

    final confirmed = await _remote.complete(
      scanId: started.id,
      checksums: [for (final shot in record.shots) shot.sha256],
    );
    record.isConfirmed = true;
    ObjectScanMapper.applyServerState(record, confirmed);
    await _local.put(record);
  }

  Future<int> _send(int scanId, ScanShotRecord shot) async {
    final image =
        await _directoryManager.resolveExistingFile(shot.file) ??
        File(shot.file);
    return _remote.uploadPhoto(
      scanId: scanId,
      openImageBytes: image.openRead,
      imageLength: await image.length(),
      fileName: p.basename(image.path),
      sha256: shot.sha256,
      capturedAt: shot.capturedAt,
    );
  }

  /// A scan keeps one copy of each photograph, and that copy is what goes
  /// once the server has them all: dozens of full-size photographs are too
  /// much to leave on a phone for nothing. The record stays, so the scan
  /// still shows which sides were shot.
  @override
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  }) async {
    final record = _local.get(localWallId);
    if (record == null) return;
    for (final shot in record.shots.where((shot) => shot.uploaded)) {
      await _local.deleteFile(shot.file);
    }
  }
}
