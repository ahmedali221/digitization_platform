import '../../domain/entities/building.dart';
import '../../domain/entities/floor.dart';
import '../../domain/entities/hall.dart';
import '../../domain/entities/object_metadata.dart';
import '../../domain/entities/object_type.dart';
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
            return _mapBuilding(
              buildingJson,
              siteRecord.siteId,
              floorsByFloorId,
              localWallStatus,
            );
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
      kind: SiteKind.fromWire(siteRecord.kind),
      downloadProgress: downloadProgress,
      lastSynced: formatRelativeTime(siteRecord.downloadedAt),
      updateAvailable: updateAvailable,
      isArchived: siteRecord.isArchived,
    );
  }

  BuildingEntity _mapBuilding(
    Map<String, dynamic> buildingJson,
    String siteId,
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
      // The bundle's own building entries never carry a site_id field (see
      // SitePackageBuilder::buildBuildingEntry) — the id this package was
      // fetched under is the only correct source, and it applies to every
      // building in it.
      siteId: siteId,
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
    // An empty wall_status_index is sometimes serialized as `[]` rather than
    // `{}` (e.g. a floor whose rooms have no walls yet) — treat anything
    // that isn't a Map as empty instead of crashing the cast.
    final rawWallStatusIndex = raw['wall_status_index'];
    final wallStatusIndex = rawWallStatusIndex is Map
        ? rawWallStatusIndex.cast<String, dynamic>()
        : const <String, dynamic>{};

    // `items` lists every record on the floor; `rooms` only those the canvas
    // draws, which leaves out a wall added after its room was drawn and any
    // object. A bundle published before `items` existed has only `rooms`.
    final items = (raw['items'] as List?)?.cast<Map>();
    final entries =
        items ??
        rooms.expand(
          (room) => (room['walls'] as List? ?? const []).cast<Map>(),
        );

    final walls = entries
        .map(
          (entry) => _mapWall(
            entry.cast<String, dynamic>(),
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
      halls: _mapHalls(raw['chambers'] as List?, rooms),
    );
  }

  /// The halls a new item can be filed under: the bundle's own list, or,
  /// for a bundle that predates it, the chambers its drawn rooms name.
  List<HallEntity> _mapHalls(List<dynamic>? chambers, List<Map> rooms) {
    if (chambers != null) {
      return [
        for (final chamber in chambers.cast<Map>())
          HallEntity(
            id: chamber['id'].toString(),
            name: chamber['name']?.toString() ?? '',
          ),
      ];
    }

    final byId = <String, HallEntity>{};
    for (final room in rooms) {
      final chamberId = room['chamber_id'];
      final label = room['label']?.toString() ?? '';
      if (chamberId == null || label.isEmpty) continue;
      byId.putIfAbsent(
        chamberId.toString(),
        () => HallEntity(id: chamberId.toString(), name: label),
      );
    }
    return byId.values.toList();
  }

  /// [entry] is one of the bundle's `items`, or, for an older bundle, one of
  /// a room's `walls` — which carries only `wall_id`, `name` and `edge`, so
  /// every typed field falls back to "a wall, captured as a grid".
  WallEntity _mapWall(
    Map<String, dynamic> entry,
    String floorId,
    Map<String, dynamic> wallStatusIndex,
    Map<String, WallStatusRecord> localWallStatus,
  ) {
    final wallId = entry['wall_id'].toString();
    final serverEntry = (wallStatusIndex[wallId] as Map?)
        ?.cast<String, dynamic>();
    final localRecord = localWallStatus[wallId];

    // Local status is the source of truth once it exists (§4) — the
    // server-published wall_status_index only seeds the very first read.
    // lastCapture follows the exact same rule: a save on this device (which
    // is what writes localRecord.updatedAt) is more current than whatever
    // the downloaded bundle had at publish time.
    final status = localRecord != null
        ? WallStatus.values.byName(localRecord.status)
        : _parseServerStatus(serverEntry?['status'] as String?);

    final serverLastCaptureAt = serverEntry?['last_capture_at'] as String?;
    final lastCaptureAt =
        localRecord?.updatedAt ??
        (serverLastCaptureAt != null
            ? DateTime.parse(serverLastCaptureAt)
            : null);

    final objectType = ObjectType.fromWire(entry['object_type'] as String?);
    final captureModeRaw =
        entry['capture_mode'] as String? ??
        serverEntry?['capture_mode'] as String?;

    return WallEntity(
      id: wallId,
      floorId: floorId,
      // Falls back to the edge when an older published bundle predates the
      // wall-name field (see SitePackageBuilder::buildRoomFromShape).
      name:
          (entry['name'] as String?) ??
          '${_capitalize(entry['edge'] as String? ?? 'Wall')} wall',
      notes: entry['notes'] as String? ?? '',
      status: status,
      lastCapture: formatRelativeTime(lastCaptureAt),
      grid: _mapGrid(serverEntry),
      roomLabel: entry['chamber_name'] as String?,
      hallId: entry['chamber_id']?.toString(),
      objectType: objectType,
      captureMode: captureModeRaw == null
          ? objectType.captureMode
          : CaptureMode.fromWire(captureModeRaw),
      metadata: ObjectMetadata.fromWire(entry['metadata'] as Map?),
      intakeStatus: IntakeStatus.fromWire(entry['intake_status'] as String?),
      capturedSides: _mapSides(serverEntry?['sides_captured'] as List?),
    );
  }

  Set<ObjectSide> _mapSides(List<dynamic>? raw) {
    if (raw == null) return const {};
    return raw
        .map((side) => ObjectSide.fromWire(side as String?))
        .nonNulls
        .toSet();
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
