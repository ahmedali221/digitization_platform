import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../storage/hive_boxes.dart';
import '../models/floor_package_record.dart';
import '../models/id_mapping_record.dart';
import '../models/site_package_record.dart';
import '../models/wall_status_record.dart';

/// Pure Hive CRUD over the `sites`/`floors`/`wall_status`/`id_mappings`
/// boxes — no HTTP, no entity mapping. [SiteMapper] turns these records
/// into the app's domain entities.
class SiteLocalDataSource {
  final Uuid _uuid = const Uuid();

  Box<SitePackageRecord> get _sitesBox =>
      Hive.box<SitePackageRecord>(HiveBoxes.sites);

  Box<FloorPackageRecord> get _floorsBox =>
      Hive.box<FloorPackageRecord>(HiveBoxes.floors);

  Box<WallStatusRecord> get _wallStatusBox =>
      Hive.box<WallStatusRecord>(HiveBoxes.wallStatus);

  Box<IdMappingRecord> get _idMappingsBox =>
      Hive.box<IdMappingRecord>(HiveBoxes.idMappings);

  /// Untyped — a locally-added wall on an otherwise-mapped floor
  /// (`AddWallPage`), keyed by a generated `local_` id. No server
  /// counterpart or sync exists for these yet (same scope the fake
  /// repository already had); full local-id resolution is Phase 5.
  Box get _unassignedBox => Hive.box(HiveBoxes.unassigned);

  List<SitePackageRecord> allSites() => _sitesBox.values.toList();

  Stream<List<SitePackageRecord>> watchSites() async* {
    yield allSites();
    yield* _sitesBox.watch().map((_) => allSites());
  }

  Future<void> putSite(SitePackageRecord record) =>
      _sitesBox.put(record.siteId, record);

  SitePackageRecord? getSite(String siteId) => _sitesBox.get(siteId);

  Future<void> deleteSite(String siteId) => _sitesBox.delete(siteId);

  List<FloorPackageRecord> floorsForSite(String siteId) =>
      _floorsBox.values.where((f) => f.siteId == siteId).toList();

  Future<void> putFloor(FloorPackageRecord record) =>
      _floorsBox.put(record.floorId, record);

  FloorPackageRecord? getFloor(String floorId) => _floorsBox.get(floorId);

  Map<String, WallStatusRecord> allWallStatus() => {
    for (final record in _wallStatusBox.values) record.wallId: record,
  };

  WallStatusRecord? getWallStatus(String wallId) => _wallStatusBox.get(wallId);

  Stream<void> watchWallStatus() => _wallStatusBox.watch();

  Future<void> putWallStatus(WallStatusRecord record) =>
      _wallStatusBox.put(record.wallId, record);

  Future<void> putIdMapping(IdMappingRecord record) =>
      _idMappingsBox.put(record.localId, record);

  IdMappingRecord? getIdMapping(String localId) => _idMappingsBox.get(localId);

  Future<String> addLocalWall({
    required String floorId,
    required String title,
    String notes = '',
  }) async {
    final localId = 'local_${_uuid.v4().substring(0, 8)}';
    await _unassignedBox.put(localId, {
      'floorId': floorId,
      'title': title,
      'notes': notes,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return localId;
  }

  Map<String, Map<String, dynamic>> localWallsForFloor(String floorId) {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _unassignedBox.keys) {
      final value = (_unassignedBox.get(key) as Map).cast<String, dynamic>();
      if (value['floorId'] == floorId) {
        result[key as String] = value;
      }
    }
    return result;
  }

  /// Every locally-added wall stub across all floors, keyed by `local_id` —
  /// the unassigned-walls feature's source of truth for "which off-map
  /// walls exist," independent of which floor each one belongs to.
  Map<String, Map<String, dynamic>> allLocalWalls() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _unassignedBox.keys) {
      result[key as String] = (_unassignedBox.get(key) as Map)
          .cast<String, dynamic>();
    }
    return result;
  }

  Stream<void> watchLocalWalls() => _unassignedBox.watch();
}
