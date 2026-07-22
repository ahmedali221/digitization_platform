import '../entities/building.dart';
import '../entities/floor.dart';
import '../entities/site.dart';
import '../entities/wall.dart';

/// Site package tree (sites → buildings → floors → walls). In the real data
/// layer this splits into a bundle-read repository (Hive `sites`/`floors`
/// boxes) and a local wall-status write repository (Hive `wall_status` box,
/// FLUTTER_MOBILE_PLAN.md §3) — merged here for the UI-first pass since both
/// read from the same in-memory tree today.
abstract class SiteRepository {
  Stream<List<SiteEntity>> watchSites();

  SiteEntity? findSite(String siteId);

  BuildingEntity? findBuilding(String buildingId);

  FloorEntity? findFloor(String floorId);

  WallEntity? findWall(String floorId, String wallId);

  Future<void> startDownload(String siteId);

  /// Applies [update] to the wall and pushes the mutated tree to
  /// [watchSites]'s listeners.
  void updateWall(
    String floorId,
    String wallId,
    WallEntity Function(WallEntity current) update,
  );

  /// Creates a new wall on [floorId] with the given [title]/[notes] and
  /// pushes the mutated tree to [watchSites]'s listeners.
  void addWall(String floorId, {required String title, String notes = ''});
}
