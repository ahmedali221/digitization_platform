import 'dart:async';

import '../../../../core/data/datasources/site_local_data_source.dart';
import '../../../../core/data/models/id_mapping_record.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/storage/device_id_provider.dart';
import '../../../grid_capture/data/datasources/capture_session_local_data_source.dart';
import '../../../grid_capture/data/models/capture_session_record.dart';
import '../../../sync_queue/domain/repositories/sync_enqueuer.dart';
import '../../domain/entities/unassigned_wall.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';
import '../datasources/unassigned_capture_local_data_source.dart';
import '../datasources/unassigned_wall_remote_data_source.dart';
import '../models/unassigned_capture_record.dart';

/// Real, Hive+Dio-backed [UnassignedWallRepository]. Wall-stub metadata
/// (title/notes/floorId) stays owned by [SiteLocalDataSource] — this class
/// only adds the capture/sync lifecycle on top, keyed by the same
/// `local_id`. See the type's doc comment for the overall Phase 5 design.
class UnassignedWallRepositoryImpl implements UnassignedWallRepository {
  UnassignedWallRepositoryImpl({
    required SiteLocalDataSource siteLocal,
    required SiteRepository siteRepository,
    required UnassignedCaptureLocalDataSource captureLocal,
    required UnassignedWallRemoteDataSource remote,
    required DeviceIdProvider deviceIdProvider,
    required CaptureSessionLocalDataSource sessionLocal,
    required SyncEnqueuer syncEnqueuer,
  }) : _siteLocal = siteLocal,
       _siteRepository = siteRepository,
       _captureLocal = captureLocal,
       _remote = remote,
       _deviceIdProvider = deviceIdProvider,
       _sessionLocal = sessionLocal,
       _syncEnqueuer = syncEnqueuer {
    _localWallsSub = _siteLocal.watchLocalWalls().listen((_) => _emit());
    _captureSub = _captureLocal.watchAll().listen((_) => _emit());
  }

  final SiteLocalDataSource _siteLocal;
  final SiteRepository _siteRepository;
  final UnassignedCaptureLocalDataSource _captureLocal;
  final UnassignedWallRemoteDataSource _remote;
  final DeviceIdProvider _deviceIdProvider;
  final CaptureSessionLocalDataSource _sessionLocal;
  final SyncEnqueuer _syncEnqueuer;

  final _controller = StreamController<List<UnassignedWall>>.broadcast();
  late final StreamSubscription<void> _localWallsSub;
  late final StreamSubscription<void> _captureSub;

  @override
  Stream<List<UnassignedWall>> watchUnassignedWalls() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  UnassignedWall? findByLocalId(String localId) {
    final stub = _siteLocal.allLocalWalls()[localId];
    return stub == null ? null : _toEntity(localId, stub);
  }

  @override
  Future<void> appendShot(
    String localId,
    String filePath,
    String sha256,
  ) async {
    await _captureLocal.recordShot(
      localId: localId,
      filePath: filePath,
      sha256: sha256,
    );
  }

  @override
  Future<void> removeShot(String localId, String filePath) async {
    await _captureLocal.removeShot(localId: localId, filePath: filePath);
  }

  @override
  Future<void> syncMetadata(String localId) async {
    final stub = _siteLocal.allLocalWalls()[localId];
    if (stub == null) return;

    final floorId = stub['floorId'] as String;
    final siteId = _siteLocal.getFloor(floorId)?.siteId ?? '';
    final deviceId = await _deviceIdProvider.getOrCreateDeviceId();
    final notes = stub['notes'] as String?;
    final capture = await _captureLocal.ensure(
      localId: localId,
      siteId: siteId,
      floorId: floorId,
    );

    await _remote.syncUnassigned(
      localId: localId,
      siteId: siteId,
      deviceId: deviceId,
      notes: notes,
      capturedAt: capture.createdAt,
    );

    capture.syncStatus = 'awaitingResolution';
    capture.lastSyncedAt = DateTime.now();
    await capture.save();
  }

  @override
  Future<void> checkResolution(String localId) async {
    final mappings = await _fetchMappings();
    await _applyMapping(localId, mappings);
  }

  @override
  Future<void> checkAllResolutions() async {
    final pending = _captureLocal
        .all()
        .where((c) => c.syncStatus == 'awaitingResolution')
        .map((c) => c.localId);
    if (pending.isEmpty) return;

    final mappings = await _fetchMappings();
    for (final localId in pending) {
      await _applyMapping(localId, mappings);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMappings() async {
    final deviceId = await _deviceIdProvider.getOrCreateDeviceId();
    return _remote.fetchMappings(deviceId: deviceId);
  }

  Future<void> _applyMapping(
    String localId,
    List<Map<String, dynamic>> mappings,
  ) async {
    Map<String, dynamic>? match;
    for (final mapping in mappings) {
      if (mapping['local_id'] == localId) {
        match = mapping;
        break;
      }
    }
    if (match == null) return;

    final wallId = match['wall_id'].toString();
    final resolvedAt =
        DateTime.tryParse(match['resolved_at'] as String? ?? '') ??
        DateTime.now();

    await _siteLocal.putIdMapping(
      IdMappingRecord(localId: localId, wallId: wallId, resolvedAt: resolvedAt),
    );

    final capture = _captureLocal.get(localId);
    if (capture == null) return;
    capture.resolvedWallId = wallId;
    capture.syncStatus = 'resolved';
    await capture.save();
  }

  @override
  Future<void> promoteToRealWall(String localId) async {
    final capture = _captureLocal.get(localId);
    final resolvedWallId = capture?.resolvedWallId;
    if (capture == null || resolvedWallId == null || capture.shots.isEmpty) {
      return;
    }

    final cells = [
      for (var i = 0; i < capture.shots.length; i++)
        CaptureCellRecord(
          row: 0,
          col: i,
          photos: [
            CapturePhotoRecord(
              file: capture.shots[i],
              sha256: capture.checksums[i],
              shot: 1,
              capturedAt: capture.createdAt,
            ),
          ],
        ),
    ];

    // This wall was just resolved on the dashboard, so it may not exist in
    // this device's locally cached site bundle yet — unlike
    // GridCaptureRepositoryImpl's finalize step, there's deliberately no
    // local WallStatus/SiteRepository update here; the enqueue below is what
    // actually gets these photos to the server, which is what matters.
    await _sessionLocal.put(
      CaptureSessionRecord(
        sessionId: resolvedWallId,
        wallId: resolvedWallId,
        floorId: capture.floorId,
        siteId: capture.siteId,
        gridRows: 1,
        gridCols: capture.shots.length,
        cells: cells,
        state: 'completed',
        createdAt: capture.createdAt,
        completedAt: DateTime.now(),
      ),
    );

    final stub = _siteLocal.allLocalWalls()[localId];
    final displayName = (stub?['title'] as String?) ?? localId;
    await _syncEnqueuer.enqueueSession(
      wallId: resolvedWallId,
      siteId: capture.siteId,
      displayName: displayName,
    );
  }

  List<UnassignedWall> _snapshot() => _siteLocal
      .allLocalWalls()
      .entries
      .map((entry) => _toEntity(entry.key, entry.value))
      .toList();

  UnassignedWall _toEntity(String localId, Map<String, dynamic> stub) {
    final floorId = stub['floorId'] as String;
    final floor = _siteRepository.findFloor(floorId);
    final siteId = _siteLocal.getFloor(floorId)?.siteId ?? '';
    final capture = _captureLocal.get(localId);
    final createdAtRaw = stub['createdAt'] as String?;

    return UnassignedWall(
      id: localId,
      localId: localId,
      title: (stub['title'] as String?) ?? localId,
      siteId: siteId,
      buildingId: floor?.buildingId ?? '',
      floorId: floorId,
      photoCount: capture?.shots.length ?? 0,
      notes: stub['notes'] as String? ?? '',
      capturedAt: createdAtRaw != null
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
          : DateTime.now(),
      syncStatus: _syncStatusOf(capture),
      resolvedWallId: capture?.resolvedWallId,
    );
  }

  UnassignedWallSyncStatus _syncStatusOf(UnassignedCaptureRecord? capture) {
    return switch (capture?.syncStatus) {
      'resolved' => UnassignedWallSyncStatus.resolved,
      'awaitingResolution' => UnassignedWallSyncStatus.awaitingResolution,
      _ => UnassignedWallSyncStatus.notSynced,
    };
  }

  void _emit() => _controller.add(_snapshot());

  Future<void> dispose() async {
    await _localWallsSub.cancel();
    await _captureSub.cancel();
    await _controller.close();
  }
}
