import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/theme/wall_status.dart';
import '../../../sync_queue/domain/entities/sync_item_kind.dart';
import '../../../sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../domain/entities/object_scan.dart';
import '../../domain/entities/scan_plan.dart';
import '../../domain/repositories/object_scan_repository.dart';
import '../datasources/object_scan_local_data_source.dart';
import '../datasources/object_scan_remote_data_source.dart';
import '../mappers/object_scan_mapper.dart';
import '../models/object_scan_record.dart';

/// Real, Hive+file-backed [ObjectScanRepository]. The upload itself belongs
/// to the sync queue (`ObjectScanUploader`); this hands the scan over to it
/// and reads back what the server made of it.
class ObjectScanRepositoryImpl implements ObjectScanRepository {
  ObjectScanRepositoryImpl({
    required SiteRepository siteRepository,
    required ObjectScanLocalDataSource local,
    required ObjectScanRemoteDataSource remote,
    required SyncEnqueuer syncEnqueuer,
  }) : _siteRepository = siteRepository,
       _local = local,
       _remote = remote,
       _syncEnqueuer = syncEnqueuer;

  final SiteRepository _siteRepository;
  final ObjectScanLocalDataSource _local;
  final ObjectScanRemoteDataSource _remote;
  final SyncEnqueuer _syncEnqueuer;

  @override
  ObjectScan? getScan(String wallId) =>
      ObjectScanMapper.toEntity(_local.get(wallId));

  @override
  Stream<ObjectScan?> watchScan(String wallId) async* {
    yield getScan(wallId);
    yield* _local.watch(wallId).map((_) => getScan(wallId));
  }

  @override
  Future<String> incomingFolder(String wallId) async =>
      (await _local.incomingDir(wallId)).path;

  @override
  Future<void> addShot({
    required String floorId,
    required String wallId,
    required String shotPath,
    required ScanCell cell,
  }) async {
    final record = _local.get(wallId) ?? _newRecord(floorId, wallId);
    final now = DateTime.now();
    final kept = await _local.keepShot(
      wallId: wallId,
      // The time keeps a retake of the same slice from overwriting the
      // photograph it replaces.
      fileName:
          'scan_${cell.ring}_${cell.sector}_${now.millisecondsSinceEpoch}.jpg',
      sourcePath: shotPath,
    );
    record
      ..shots = [
        ...record.shots,
        ScanShotRecord(
          file: kept.path,
          sha256: kept.sha256,
          capturedAt: now,
          ring: cell.ring,
          sector: cell.sector,
        ),
      ]
      ..cellsToRetake = ObjectScanMapper.pairsOf(
        ObjectScanMapper.toEntity(record)!.cellsToRetake.difference({cell}),
      );
    await _local.put(record);
  }

  @override
  Future<void> finish({
    required String floorId,
    required String wallId,
    required bool fullCircle,
  }) async {
    final record = _local.get(wallId);
    if (record == null || record.shots.isEmpty) return;

    record
      ..isFinished = true
      ..isConfirmed = false
      ..fullCircle = fullCircle;
    // A record made while the floor's site could not be resolved would be
    // refused at upload; the site is known by the time a scan is finished.
    if (record.siteId.isEmpty) record.siteId = _siteIdForFloor(floorId) ?? '';
    await _local.put(record);

    _siteRepository.updateWall(
      floorId,
      wallId,
      (current) => current.copyWith(
        status: current.status == WallStatus.notStarted
            ? WallStatus.inProgress
            : current.status,
        lastCapture: 'just now',
      ),
    );

    await _syncEnqueuer.enqueueCapture(
      wallId: wallId,
      siteId: record.siteId,
      displayName: _siteRepository.findWall(floorId, wallId)?.name ?? wallId,
      kind: SyncItemKind.objectScan,
    );
  }

  @override
  Future<void> reopen(String wallId, {bool fromTheStart = false}) async {
    final record = _local.get(wallId);
    if (record == null) return;

    final missingParts = ObjectScanMapper.toEntity(record)!.missingParts;
    var unusable = record.shots
        .where((shot) => ObjectScanMapper.isUnusable(record, shot))
        .toList();
    // The server asked for more without saying where: nothing it was sent
    // can be trusted to be the part that worked, so the scan starts over.
    final saidWhere = unusable.isNotEmpty || missingParts.isNotEmpty;
    if (fromTheStart || !saidWhere) unusable = record.shots;

    final roughModel = record.previewModelFile;
    record
      ..shots = record.shots.where((shot) => !unusable.contains(shot)).toList()
      ..cellsToRetake = fromTheStart
          ? const []
          : ObjectScanMapper.pairsOf(missingParts)
      ..isFinished = false
      ..isConfirmed = false;
    ObjectScanMapper.clearServerState(record);
    await _local.put(record);

    for (final shot in unusable) {
      await _deleteFile(shot.file);
    }
    // It showed the scan as it was; the next round gets a model of its own.
    if (roughModel != null) await _deleteFile(roughModel);
  }

  @override
  Future<void> refreshStatus(String wallId) async {
    final record = _local.get(wallId);
    final scanId = record?.serverScanId;
    if (record == null || scanId == null || !record.isConfirmed) return;

    final state = await _remote.fetch(scanId);
    ObjectScanMapper.applyServerState(record, state);
    await _local.put(record);

    final preview = state.preview;
    if (preview != null &&
        preview.hasModel &&
        record.previewModelFile == null) {
      final file = await _local.newPreviewFile(wallId, preview.id);
      await _remote.downloadPreview(scanId: scanId, savePath: file);
      record.previewModelFile = file;
      await _local.put(record);
    }
  }

  ObjectScanRecord _newRecord(String floorId, String wallId) {
    return ObjectScanRecord(
      wallId: wallId,
      floorId: floorId,
      siteId: _siteIdForFloor(floorId) ?? '',
      clientUuid: const Uuid().v4(),
      shots: [],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _deleteFile(String filePath) async {
    try {
      await _local.deleteFile(filePath);
    } catch (error) {
      // The record is authoritative: a file that could not be removed must
      // not bring a discarded photograph back into the scan.
      debugPrint(
        'ObjectScanRepositoryImpl: failed to delete $filePath: $error',
      );
    }
  }

  String? _siteIdForFloor(String floorId) {
    final floor = _siteRepository.findFloor(floorId);
    if (floor == null) return null;
    return _siteRepository.findBuilding(floor.buildingId)?.siteId;
  }
}
