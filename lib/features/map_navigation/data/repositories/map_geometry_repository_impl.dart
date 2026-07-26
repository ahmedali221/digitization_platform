import '../../../../core/data/datasources/site_local_data_source.dart';
import '../../../../core/data/models/floor_package_record.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../domain/entities/map_geometry.dart';
import '../../domain/repositories/map_geometry_repository.dart';
import '../mappers/map_geometry_mapper.dart';

/// Real [MapGeometryRepository], backed by whatever bundle JSON is already
/// sitting in the `sites`/`floors` Hive boxes — no separate download or
/// storage step, since `SiteDownloadService` already persists the full
/// decoded JSON these methods read.
class MapGeometryRepositoryImpl implements MapGeometryRepository {
  MapGeometryRepositoryImpl({
    required SiteLocalDataSource local,
    required DirectoryManager directoryManager,
  }) : _local = local,
       _mapper = MapGeometryMapper(directoryManager);

  final SiteLocalDataSource _local;
  final MapGeometryMapper _mapper;

  @override
  SiteOverviewGeometry? overviewGeometryFor(String siteId) {
    final record = _local.getSite(siteId);
    if (record == null) return null;
    return _mapper.overviewGeometryFor(record);
  }

  @override
  BuildingFloorsGeometry? floorsGeometryFor(String siteId, String buildingId) {
    final record = _local.getSite(siteId);
    if (record == null) return null;
    return _mapper.floorsGeometryFor(record, buildingId);
  }

  @override
  FloorRoomsGeometry? roomsGeometryFor(String siteId, String floorId) {
    final record = _floorRecord(siteId, floorId);
    if (record == null) return null;
    return _mapper.roomsGeometryFor(record);
  }

  FloorPackageRecord? _floorRecord(String siteId, String floorId) {
    for (final record in _local.floorsForSite(siteId)) {
      if (record.floorId == floorId) return record;
    }
    return null;
  }
}
