import 'dart:async';

import '../../../features/site_sync/domain/services/site_download_service.dart';
import '../../domain/entities/building.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/site.dart';
import '../../domain/entities/wall.dart';
import '../../domain/repositories/site_repository.dart';
import '../../storage/directory_manager.dart';
import '../../theme/wall_status.dart';
import '../datasources/site_local_data_source.dart';
import '../datasources/site_remote_data_source.dart';
import '../mappers/site_mapper.dart';
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
    _localWallsSub = _local.watchLocalWalls().listen((_) => _emit());
  }

  final SiteLocalDataSource _local;
  final SiteRemoteDataSource _remote;
  final SiteDownloadService _downloadService;
  final DirectoryManager _directoryManager;
  final SiteMapper _mapper;

  final _controller = StreamController<List<SiteEntity>>.broadcast();
  late final StreamSubscription<void> _sitesSub;
  late final StreamSubscription<void> _wallStatusSub;
  late final StreamSubscription<void> _localWallsSub;

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
  void addWall(String floorId, {required String title, String notes = ''}) {
    // Local-only, same as the fake this replaces: a wall the operator adds
    // on-site that isn't in the published map yet. No server counterpart
    // or sync exists for these (full local-id resolution is Phase 5) — it
    // just needs to persist and appear locally, which this does.
    unawaited(
      _local.addLocalWall(floorId: floorId, title: title, notes: notes),
    );
  }

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
              building.floors.map((floor) => _withLocalWalls(floor)).toList(),
            ),
          )
          .toList(),
    );
  }

  FloorEntity _withLocalWalls(FloorEntity floor) {
    final localWalls = _local.localWallsForFloor(floor.id);
    if (localWalls.isEmpty) return floor;

    final added = localWalls.entries.map((entry) {
      final data = entry.value;
      return WallEntity(
        id: entry.key,
        floorId: floor.id,
        name: data['title'] as String,
        notes: data['notes'] as String? ?? '',
        status: WallStatus.notStarted,
        lastCapture: '—',
      );
    });

    return floor.copyWithWalls([...floor.walls, ...added]);
  }

  void _emit() => _controller.add(_mapAll());

  Future<void> dispose() async {
    await _sitesSub.cancel();
    await _wallStatusSub.cancel();
    await _localWallsSub.cancel();
    await _controller.close();
  }
}
