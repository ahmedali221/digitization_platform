import '../entities/map_geometry.dart';

/// Real, dashboard-drawn shape positions read out of a downloaded site's raw
/// bundle JSON. Geometry is static per downloaded bundle version, so every
/// method here is synchronous — matching the site repository's own
/// synchronous find*() methods. Each method returns null when the relevant
/// site/building/floor hasn't been downloaded, or the bundle carries no
/// manually drawn geometry; callers fall back to an auto-layout in that case.
abstract class MapGeometryRepository {
  SiteOverviewGeometry? overviewGeometryFor(String siteId);

  BuildingFloorsGeometry? floorsGeometryFor(String siteId, String buildingId);

  FloorRoomsGeometry? roomsGeometryFor(String siteId, String floorId);
}
