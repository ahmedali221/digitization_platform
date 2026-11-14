import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/new_item_draft.dart';
import '../../domain/entities/wall.dart';
import '../../storage/hive_boxes.dart';
import '../models/floor_package_record.dart';
import '../models/id_mapping_record.dart';
import '../models/local_item_stub.dart';
import '../models/site_package_record.dart';
import '../models/wall_status_record.dart';

/// Pure Hive CRUD over the `sites`/`floors`/`wall_status`/`id_mappings`
/// boxes — no HTTP, no entity mapping. [SiteMapper] turns these records
/// into the app's domain entities.
class SiteLocalDataSource {
  static const _localIdLength = 8;

  final Uuid _uuid = const Uuid();

  Box<SitePackageRecord> get _sitesBox =>
      Hive.box<SitePackageRecord>(HiveBoxes.sites);

  Box<FloorPackageRecord> get _floorsBox =>
      Hive.box<FloorPackageRecord>(HiveBoxes.floors);

  Box<WallStatusRecord> get _wallStatusBox =>
      Hive.box<WallStatusRecord>(HiveBoxes.wallStatus);

  Box<IdMappingRecord> get _idMappingsBox =>
      Hive.box<IdMappingRecord>(HiveBoxes.idMappings);

  /// Untyped: one [LocalItemStub] map per wall or object added on this
  /// phone, keyed by its `local_` id. The box keeps the name it had when
  /// these waited in the dashboard's unassigned queue.
  Box get _localItemsBox => Hive.box(HiveBoxes.unassigned);

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

  Stream<void> watchIdMappings() => _idMappingsBox.watch();

  /// Stores [draft] as a new item on [floorId] and returns its local id.
  Future<String> addLocalItem({
    required String floorId,
    required NewItemDraft draft,
  }) async {
    final clientUuid = _uuid.v4();
    final localId = _unusedLocalId(clientUuid);
    await putLocalItem(
      localId,
      LocalItemStub.fromDraft(
        floorId: floorId,
        draft: draft,
        clientUuid: clientUuid,
        createdAt: DateTime.now(),
      ),
    );
    return localId;
  }

  /// The local id is a short fragment because it names folders and shows up
  /// in logs; short means two can collide, so a taken one is skipped.
  String _unusedLocalId(String seedUuid) {
    var candidate = seedUuid;
    while (true) {
      final localId =
          '${WallEntity.localIdPrefix}'
          '${candidate.replaceAll('-', '').substring(0, _localIdLength)}';
      if (!_localItemsBox.containsKey(localId)) return localId;
      candidate = _uuid.v4();
    }
  }

  Future<void> putLocalItem(String localId, LocalItemStub stub) =>
      _localItemsBox.put(localId, stub.toMap());

  LocalItemStub? getLocalItem(String localId) {
    final stored = _localItemsBox.get(localId);
    return stored == null ? null : LocalItemStub.fromMap(stored as Map);
  }

  Map<String, LocalItemStub> localItemsForFloor(String floorId) {
    final result = <String, LocalItemStub>{};
    for (final key in _localItemsBox.keys) {
      final stub = LocalItemStub.fromMap(_localItemsBox.get(key) as Map);
      if (stub.floorId == floorId) result[key as String] = stub;
    }
    return result;
  }

  Stream<void> watchLocalItems() => _localItemsBox.watch();
}
