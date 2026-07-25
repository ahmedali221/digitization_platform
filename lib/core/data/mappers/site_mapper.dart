import '../../domain/entities/building.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/site.dart';
import '../../domain/entities/wall.dart';
import '../../theme/wall_status.dart';
import '../../utils/relative_time.dart';
import '../models/floor_package_record.dart';
import '../models/site_package_record.dart';
import '../models/wall_status_record.dart';

/// Pure JSON + local-override -> domain-entity mapping. No I/O — the
/// repository is responsible for handing this whatever records it already
/// has in memory/Hive.
class SiteMapper {
  const SiteMapper();

  SiteEntity mapSite(
    SitePackageRecord siteRecord,
    List<FloorPackageRecord> floorRecords,
    Map<String, WallStatusRecord> localWallStatus, {
    required SiteAvailability availability,
    int downloadProgress = 0,
  }) {
    final raw = siteRecord.raw;
    final floorsByFloorId = {for (final f in floorRecords) f.floorId: f};

    final buildings = raw == null
        ? const <BuildingEntity>[]
        : (raw['buildings'] as List).map((b) {
            final buildingJson = (b as Map).cast<String, dynamic>();
            return _mapBuilding(buildingJson, floorsByFloorId, localWallStatus);
          }).toList();

    final updateAvailable =
        siteRecord.isDownloaded &&
        siteRecord.latestVersion != null &&
        siteRecord.localVersion != null &&
        siteRecord.latestVersion! > siteRecord.localVersion!;

    return SiteEntity(
      id: siteRecord.siteId,
      name: siteRecord.name,
      location: siteRecord.location ?? '',
      availability: availability,
      buildings: buildings,
      downloadProgress: downloadProgress,
      lastSynced: formatRelativeTime(siteRecord.downloadedAt),
      updateAvailable: updateAvailable,
    );
  }

  BuildingEntity _mapBuilding(
    Map<String, dynamic> buildingJson,
    Map<String, FloorPackageRecord> floorsByFloorId,
    Map<String, WallStatusRecord> localWallStatus,
  ) {
    final buildingId = buildingJson['id'].toString();
    final floorRefs = (buildingJson['floors'] as List).cast<Map>();

    final floors = floorRefs.map((ref) {
      final floorId = ref['id'].toString();
      final downloaded = floorsByFloorId[floorId];
      if (downloaded == null) {
        // Referenced by the site package but not downloaded yet (e.g. an
        // in-progress or partially-resumed download) — an empty floor is
        // the honest representation until its own floor_{id}.json lands.
        return FloorEntity(
          id: floorId,
          buildingId: buildingId,
          name: ref['label']?.toString() ?? ref['name']?.toString() ?? '',
          walls: const [],
        );
      }
      return _mapFloor(downloaded, buildingId, localWallStatus);
    }).toList();

    return BuildingEntity(
      id: buildingId,
      siteId: buildingJson['site_id']?.toString() ?? '',
      name: buildingJson['name'] as String,
      floors: floors,
    );
  }

  FloorEntity _mapFloor(
    FloorPackageRecord floorRecord,
    String buildingId,
    Map<String, WallStatusRecord> localWallStatus,
  ) {
    final raw = floorRecord.raw;
    final floorJson = (raw['floor'] as Map).cast<String, dynamic>();
    final rooms = (raw['rooms'] as List? ?? const []).cast<Map>();
    final wallStatusIndex =
        (raw['wall_status_index'] as Map? ?? const {}).cast<String, dynamic>();

    final walls = rooms
        .expand((room) => (room['walls'] as List? ?? const []).cast<Map>())
        .map(
          (wallJson) => _mapWall(
            wallJson.cast<String, dynamic>(),
            floorRecord.floorId,
            wallStatusIndex,
            localWallStatus,
          ),
        )
        .toList();

    return FloorEntity(
      id: floorRecord.floorId,
      buildingId: buildingId,
      name: floorJson['name'] as String,
      walls: walls,
    );
  }

  WallEntity _mapWall(
    Map<String, dynamic> wallJson,
    String floorId,
    Map<String, dynamic> wallStatusIndex,
    Map<String, WallStatusRecord> localWallStatus,
  ) {
    final wallId = wallJson['wall_id'].toString();
    final serverEntry =
        (wallStatusIndex[wallId] as Map?)?.cast<String, dynamic>();
    final localRecord = localWallStatus[wallId];

    // Local status is the source of truth once it exists (§4) — the
    // server-published wall_status_index only seeds the very first read.
    final status = localRecord != null
        ? WallStatus.values.byName(localRecord.status)
        : _parseServerStatus(serverEntry?['status'] as String?);

    final lastCaptureAt = serverEntry?['last_capture_at'] as String?;

    return WallEntity(
      id: wallId,
      floorId: floorId,
      // Falls back to the edge when an older published bundle predates the
      // wall-name field (see SitePackageBuilder::buildRoomFromShape).
      name:
          (wallJson['name'] as String?) ??
          '${_capitalize(wallJson['edge'] as String? ?? 'Wall')} wall',
      status: status,
      lastCapture: formatRelativeTime(
        lastCaptureAt != null ? DateTime.parse(lastCaptureAt) : null,
      ),
      grid: _mapGrid(serverEntry),
    );
  }

  /// Grid *dimensions* come from the server so grid-init can be skipped for
  /// a wall the dashboard (or a prior mobile session) already gridded
  /// (Phase 3). Cells are seeded empty, never with fake shot paths — photo
  /// files live wherever they were captured (this device, another device,
  /// or the dashboard) and only this device's own local captures ever
  /// belong in `GridCell.shotPaths`; that's populated by the real
  /// grid_capture repository, not this read-path mapper.
  GridState? _mapGrid(Map<String, dynamic>? serverEntry) {
    final rows = serverEntry?['grid_rows'] as int?;
    final cols = serverEntry?['grid_cols'] as int?;
    if (rows == null || cols == null) return null;

    return GridState(
      rows: rows,
      cols: cols,
      cells: List.generate(rows * cols, (_) => const GridCell()),
    );
  }

  WallStatus _parseServerStatus(String? raw) {
    return switch (raw) {
      'in_progress' => WallStatus.inProgress,
      'captured' => WallStatus.captured,
      'done' => WallStatus.done,
      'skipped' => WallStatus.skipped,
      _ => WallStatus.notStarted,
    };
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
