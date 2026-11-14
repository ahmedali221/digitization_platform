import 'dart:async';

import '../../../features/site_sync/domain/services/site_download_service.dart';
import '../../domain/entities/building.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/hall.dart';
import '../../domain/entities/new_item_draft.dart';
import '../../domain/entities/site.dart';
import '../../domain/entities/wall.dart';
import '../../domain/repositories/site_repository.dart';
import '../../storage/directory_manager.dart';
import '../../theme/wall_status.dart';
import '../../utils/relative_time.dart';
import '../datasources/site_local_data_source.dart';
import '../datasources/site_remote_data_source.dart';
import '../mappers/site_mapper.dart';
import '../models/local_item_stub.dart';
import '../models/site_package_record.dart';
import '../models/wall_status_record.dart';

/// Real, Hive+Dio-backed [SiteRepository]. `watchSites()` always reads from
/// local storage — [refreshCatalog] and [startDownload] are the only two
/// places this repository touches the network; a "ready" site never does
/// (Phase 1's own acceptance rule).
class SiteRepositoryImpl implements SiteRepository {
  SiteRepositoryImpl({
    required SiteLocalDataSource local,
    required SiteRemoteDataSource remote,
    required SiteDownloadService downloadService,
    required DirectoryManager directoryManager,
    SiteMapper mapper = const SiteMapper(),
  }) : _local = local,
       _remote = remote,
       _downloadService = downloadService,
       _directoryManager = directoryManager,
       _mapper = mapper {
    _sitesSub = _local.watchSites().listen((_) => _emit());
    _wallStatusSub = _local.watchWallStatus().listen((_) => _emit());
    _localItemsSub = _local.watchLocalItems().listen((_) => _emit());
    _idMappingsSub = _local.watchIdMappings().listen((_) => _emit());
  }

  final SiteLocalDataSource _local;
  final SiteRemoteDataSource _remote;
  final SiteDownloadService _downloadService;
  final DirectoryManager _directoryManager;
  final SiteMapper _mapper;

  final _controller = StreamController<List<SiteEntity>>.broadcast();
  late final StreamSubscription<void> _sitesSub;
  late final StreamSubscription<void> _wallStatusSub;
  late final StreamSubscription<void> _localItemsSub;
  late final StreamSubscription<void> _idMappingsSub;

  /// Sites currently mid-download and their 0-100 progress. Deliberately
  /// in-memory only — an interrupted download just restarts, there is
  /// nothing meaningful to resume mid-file for a JSON+image bundle this
  /// size (unlike a capture session, which has its own durable manifest).
  final Map<String, int> _downloadProgress = {};

  @override
  Stream<List<SiteEntity>> watchSites() async* {
    yield _mapAll();
    yield* _controller.stream;
  }

  @override
  SiteEntity? findSite(String siteId) {
    final record = _local.getSite(siteId);
    return record == null ? null : _mapOne(record);
  }

  @override
  BuildingEntity? findBuilding(String buildingId) {
    for (final site in _mapAll()) {
      for (final building in site.buildings) {
        if (building.id == buildingId) return building;
      }
    }
    return null;
  }

  @override
  FloorEntity? findFloor(String floorId) {
    for (final site in _mapAll()) {
      for (final building in site.buildings) {
        for (final floor in building.floors) {
          if (floor.id == floorId) return floor;
        }
      }
    }
    return null;
  }

  @override
  WallEntity? findWall(String floorId, String wallId) {
    final floor = findFloor(floorId);
    if (floor == null) return null;
    for (final wall in floor.walls) {
      if (wall.id == wallId) return wall;
    }
    return null;
  }

  @override
  Future<void> refreshCatalog() async {
    final summaries = await _remote.fetchSiteSummaries();
    for (final summary in summaries) {
      final existing = _local.getSite(summary.id);
      await _local.putSite(
        (existing ?? SitePackageRecord(siteId: summary.id, name: summary.name))
            .copyWith(
              name: summary.name,
              kind: summary.kind,
              location: summary.location,
              latestVersion: summary.latestVersion,
              latestPublishedAt: summary.latestPublishedAt,
            ),
      );
    }
  }

  @override
  Future<({int fileCount, int totalBytes})> estimateDownload(
    String siteId,
  ) async {
    final estimate = await _downloadService.estimate(siteId);
    return (fileCount: estimate.fileCount, totalBytes: estimate.totalBytes);
  }

  @override
  Future<void> startDownload(String siteId) async {
    _downloadProgress[siteId] = 0;
    _emit();
    try {
      await _downloadService.downloadSite(
        siteId,
        onProgress: (completed, total) {
          _downloadProgress[siteId] = total == 0
              ? 0
              : ((completed / total) * 100).round();
          _emit();
        },
      );
    } finally {
      _downloadProgress.remove(siteId);
      _emit();
    }
  }

  @override
  Future<void> deleteCachedSite(String siteId) async {
    await _local.deleteSite(siteId);
    await _directoryManager.deletePackage(siteId);
  }

  @override
  Future<void> archiveSite(String siteId) => _setArchived(siteId, true);

  @override
  Future<void> unarchiveSite(String siteId) => _setArchived(siteId, false);

  Future<void> _setArchived(String siteId, bool isArchived) async {
    final record = _local.getSite(siteId);
    if (record == null) return;
    await _local.putSite(record.copyWith(isArchived: isArchived));
  }

  @override
  void updateWall(
    String floorId,
    String wallId,
    WallEntity Function(WallEntity current) update,
  ) {
    final current = findWall(floorId, wallId);
    if (current == null) return;
    final updated = update(current);
    unawaited(
      _local.putWallStatus(
        WallStatusRecord(
          wallId: wallId,
          status: updated.status.name,
          dirty: true,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<String> addItem(String floorId, NewItemDraft draft) =>
      _local.addLocalItem(floorId: floorId, draft: draft);

  List<SiteEntity> _mapAll() =>
      _local.allSites().map(_mapOne).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  SiteEntity _mapOne(SitePackageRecord record) {
    final availability = _downloadProgress.containsKey(record.siteId)
        ? SiteAvailability.downloading
        : (record.isDownloaded
              ? SiteAvailability.ready
              : SiteAvailability.notDownloaded);

    final site = _mapper.mapSite(
      record,
      _local.floorsForSite(record.siteId),
      _local.allWallStatus(),
      availability: availability,
      downloadProgress: _downloadProgress[record.siteId] ?? 0,
    );

    return site.copyWith(
      buildings: site.buildings
          .map(
            (building) => building.copyWithFloors(
              building.floors
                  .map(
                    (floor) => _withLocalItems(floor, record.bundlePublishedAt),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  /// Folds the items added on this phone into [floor].
  ///
  /// Such an item keeps its `local_` id here for good: its photos, capture
  /// record and queue entry are all keyed by it. Once the server has given
  /// it a wall id and a bundle carries that wall, the two are one record —
  /// shown once, under the local id, with the bundle's fields. And when a
  /// bundle built after the item was sent does not carry it, the server has
  /// archived it (rejected, or removed), so it is dropped here too.
  FloorEntity _withLocalItems(FloorEntity floor, DateTime? bundlePublishedAt) {
    final stubs = _local.localItemsForFloor(floor.id);
    if (stubs.isEmpty) return floor;

    final wallStatus = _local.allWallStatus();
    final publishedById = {for (final wall in floor.walls) wall.id: wall};
    final local = <WallEntity>[];
    final absorbedServerIds = <String>{};

    for (final entry in stubs.entries) {
      final mapping = _local.getIdMapping(entry.key);
      final published = publishedById[mapping?.wallId];

      final isGoneFromServer =
          mapping != null &&
          published == null &&
          bundlePublishedAt != null &&
          mapping.resolvedAt.isBefore(bundlePublishedAt);
      if (isGoneFromServer) continue;

      if (published != null) absorbedServerIds.add(published.id);
      local.add(
        _localItem(
          localId: entry.key,
          stub: entry.value,
          floorId: floor.id,
          statusRecord: wallStatus[entry.key],
          serverId: mapping?.wallId,
          published: published,
        ),
      );
    }

    return floor.copyWith(
      walls: [
        ...floor.walls.where((wall) => !absorbedServerIds.contains(wall.id)),
        ...local,
      ],
      halls: _withLocalHalls(floor.halls, stubs.values),
    );
  }

  WallEntity _localItem({
    required String localId,
    required LocalItemStub stub,
    required String floorId,
    required WallStatusRecord? statusRecord,
    required String? serverId,
    required WallEntity? published,
  }) {
    return WallEntity(
      id: localId,
      floorId: floorId,
      name: published?.name ?? stub.name,
      notes: published?.notes ?? stub.notes,
      status: statusRecord != null
          ? WallStatus.values.byName(statusRecord.status)
          : published?.status ?? WallStatus.notStarted,
      lastCapture: statusRecord != null
          ? formatRelativeTime(statusRecord.updatedAt)
          : published?.lastCapture ?? formatRelativeTime(null),
      grid: published?.grid,
      roomLabel: published?.roomLabel ?? stub.hallName,
      hallId: published?.hallId ?? stub.hallId,
      objectType: published?.objectType ?? stub.objectType,
      captureMode: published?.captureMode ?? stub.captureMode,
      metadata: published?.metadata ?? stub.metadata,
      intakeStatus: published?.intakeStatus ?? stub.intakeStatus,
      capturedSides: published?.capturedSides ?? const {},
      serverId: serverId,
    );
  }

  /// A hall an operator named on this phone is offered again for the next
  /// item, without waiting for the server to create it.
  List<HallEntity> _withLocalHalls(
    List<HallEntity> published,
    Iterable<LocalItemStub> stubs,
  ) {
    final knownNames = {for (final hall in published) hall.name.toLowerCase()};
    final added = <HallEntity>[];
    for (final stub in stubs) {
      final hall = stub.hall;
      if (hall == null || !knownNames.add(hall.name.toLowerCase())) continue;
      added.add(hall);
    }
    return [...published, ...added];
  }

  void _emit() => _controller.add(_mapAll());

  Future<void> dispose() async {
    await _sitesSub.cancel();
    await _wallStatusSub.cancel();
    await _localItemsSub.cancel();
    await _idMappingsSub.cancel();
    await _controller.close();
  }
}
