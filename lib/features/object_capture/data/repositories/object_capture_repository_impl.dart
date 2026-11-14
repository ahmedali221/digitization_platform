import 'package:flutter/foundation.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../sync_queue/domain/entities/sync_item_kind.dart';
import '../../../sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../domain/entities/object_capture.dart';
import '../../domain/repositories/object_capture_repository.dart';
import '../datasources/object_capture_local_data_source.dart';
import '../models/object_capture_record.dart';

/// Real, Hive+file-backed [ObjectCaptureRepository]. Wall status stays with
/// [SiteRepository]; this owns only the photographs of one object.
class ObjectCaptureRepositoryImpl implements ObjectCaptureRepository {
  ObjectCaptureRepositoryImpl({
    required SiteRepository siteRepository,
    required ObjectCaptureLocalDataSource local,
    required SyncEnqueuer syncEnqueuer,
  }) : _siteRepository = siteRepository,
       _local = local,
       _syncEnqueuer = syncEnqueuer;

  static const _freeFileStem = 'free';

  final SiteRepository _siteRepository;
  final ObjectCaptureLocalDataSource _local;
  final SyncEnqueuer _syncEnqueuer;

  /// Counts kept shots, so two kept within the same millisecond still get
  /// different file names.
  int _keptShots = 0;

  @override
  ObjectCapture getCapture(String wallId) => _toEntity(_local.get(wallId));

  @override
  Stream<ObjectCapture> watchCapture(String wallId) async* {
    yield getCapture(wallId);
    yield* _local.watch(wallId).map((_) => getCapture(wallId));
  }

  @override
  Future<String> incomingFolder(String wallId) async =>
      (await _local.incomingDir(wallId)).path;

  @override
  Future<void> setSidePhoto({
    required String floorId,
    required String wallId,
    required ObjectSide side,
    required String shotPath,
  }) async {
    final record = _recordFor(floorId, wallId);
    final kept = await _keep(wallId, side.name, shotPath, side: side.name);

    final replaced = record.photos
        .where((photo) => photo.side == side.name)
        .toList();
    record.photos = [
      ...record.photos.where((photo) => photo.side != side.name),
      kept,
    ];
    await _local.put(record);

    for (final photo in replaced) {
      await _deleteFile(wallId, photo.file);
    }
  }

  @override
  Future<void> addFreePhotos({
    required String floorId,
    required String wallId,
    required List<String> shotPaths,
  }) async {
    if (shotPaths.isEmpty) return;
    final record = _recordFor(floorId, wallId);

    for (final shotPath in shotPaths) {
      // Stored shot by shot: if the fourth of five cannot be kept, the first
      // three are already safe in the record.
      record.photos = [
        ...record.photos,
        await _keep(wallId, _freeFileStem, shotPath),
      ];
      await _local.put(record);
    }
  }

  @override
  Future<void> adoptStrayShots({
    required String floorId,
    required String wallId,
  }) async {
    await addFreePhotos(
      floorId: floorId,
      wallId: wallId,
      shotPaths: await _local.strayShotPaths(wallId),
    );
  }

  @override
  Future<void> setComment({
    required String wallId,
    required String photoPath,
    required String comment,
  }) async {
    final record = _local.get(wallId);
    if (record == null) return;

    record.photos = [
      for (final photo in record.photos)
        // Changed after the photo was sent: the server has the picture but
        // an older description, so it goes up again.
        photo.file == photoPath
            ? photo.copyWith(comment: comment, uploaded: false)
            : photo,
    ];
    await _local.put(record);
  }

  @override
  Future<void> deletePhoto({
    required String wallId,
    required String photoPath,
  }) async {
    final record = _local.get(wallId);
    if (record == null) return;

    record.photos = record.photos
        .where((photo) => photo.file != photoPath)
        .toList();
    await _local.put(record);
    await _deleteFile(wallId, photoPath);
  }

  @override
  Future<void> save({required String floorId, required String wallId}) async {
    final record = _local.get(wallId);
    if (record == null) return;

    // A record made while the floor's site could not be resolved would be
    // refused at upload; the site is known by the time anything is saved.
    if (record.siteId.isEmpty) {
      record.siteId = _siteIdForFloor(floorId) ?? '';
      await _local.put(record);
    }

    final capture = _toEntity(record);
    _siteRepository.updateWall(
      floorId,
      wallId,
      (current) => current.copyWith(
        status: _statusFor(capture),
        lastCapture: 'just now',
      ),
    );

    if (capture.isEmpty) return;
    await _syncEnqueuer.enqueueCapture(
      wallId: wallId,
      siteId: record.siteId,
      displayName: _siteRepository.findWall(floorId, wallId)?.name ?? wallId,
      kind: SyncItemKind.objectPhotos,
    );
  }

  WallStatus _statusFor(ObjectCapture capture) {
    if (capture.isEmpty) return WallStatus.notStarted;
    return capture.isComplete ? WallStatus.captured : WallStatus.inProgress;
  }

  ObjectCaptureRecord _recordFor(String floorId, String wallId) {
    return _local.get(wallId) ??
        ObjectCaptureRecord(
          wallId: wallId,
          floorId: floorId,
          siteId: _siteIdForFloor(floorId) ?? '',
          photos: [],
          createdAt: DateTime.now(),
        );
  }

  Future<ObjectPhotoRecord> _keep(
    String wallId,
    String stem,
    String shotPath, {
    String? side,
  }) async {
    final now = DateTime.now();
    final kept = await _local.keepShot(
      wallId: wallId,
      fileStem: '${stem}_${now.millisecondsSinceEpoch}_${_keptShots++}',
      sourcePath: shotPath,
    );
    return ObjectPhotoRecord(
      file: kept.path,
      sha256: kept.sha256,
      capturedAt: now,
      side: side,
    );
  }

  Future<void> _deleteFile(String wallId, String filePath) async {
    try {
      await _local.deleteShot(wallId: wallId, filePath: filePath);
    } catch (error) {
      // The record is authoritative: a file that could not be removed must
      // not bring a discarded photograph back into the capture or the upload.
      debugPrint(
        'ObjectCaptureRepositoryImpl: failed to delete $filePath: $error',
      );
    }
  }

  ObjectCapture _toEntity(ObjectCaptureRecord? record) {
    if (record == null) return ObjectCapture.empty;
    return ObjectCapture(
      photos: [
        for (final photo in record.photos)
          ObjectPhoto(
            path: photo.file,
            capturedAt: photo.capturedAt,
            side: ObjectSide.fromWire(photo.side),
            comment: photo.comment ?? '',
            isUploaded: photo.uploaded,
          ),
      ],
    );
  }

  String? _siteIdForFloor(String floorId) {
    final floor = _siteRepository.findFloor(floorId);
    if (floor == null) return null;
    return _siteRepository.findBuilding(floor.buildingId)?.siteId;
  }
}
