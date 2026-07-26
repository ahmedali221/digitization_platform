import '../../domain/entities/map_geometry.dart';
import '../../domain/repositories/map_geometry_repository.dart';

/// Always reports "no geometry available", so every canvas falls back to
/// `CanvasLayout`'s auto-grid — matching how `FakeSiteRepository` stays a
/// plain in-memory double. Used by `test/widget_test.dart`'s manual DI
/// fixture, which never has a real downloaded bundle to read geometry from.
class FakeMapGeometryRepository implements MapGeometryRepository {
  const FakeMapGeometryRepository();

  @override
  SiteOverviewGeometry? overviewGeometryFor(String siteId) => null;

  @override
  BuildingFloorsGeometry? floorsGeometryFor(String siteId, String buildingId) =>
      null;

  @override
  FloorRoomsGeometry? roomsGeometryFor(String siteId, String floorId) => null;
}
