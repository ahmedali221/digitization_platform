import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/repositories/map_geometry_repository.dart';
import 'floor_walls_state.dart';

/// Watches the repository's site tree and derives the [siteId] building and
/// its [floorId] floor, so [FloorWallsPage] reflects wall-status/wall-list
/// changes live (e.g. after a capture session or a new wall is added).
class FloorWallsCubit extends Cubit<FloorWallsState> {
  FloorWallsCubit(
    this._repository,
    this._geometryRepository,
    this._siteId,
    this._buildingId,
    this._floorId,
  ) : super(const FloorWallsLoading()) {
    _subscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(FloorWallsError(error.toString())),
    );
  }

  final SiteRepository _repository;
  final MapGeometryRepository _geometryRepository;
  final String _siteId;
  final String _buildingId;
  final String _floorId;
  late final StreamSubscription<List<SiteEntity>> _subscription;

  void _onSitesChanged(List<SiteEntity> sites) {
    for (final site in sites) {
      if (site.id != _siteId) continue;
      for (final building in site.buildings) {
        if (building.id != _buildingId) continue;
        for (final floor in building.floors) {
          if (floor.id == _floorId) {
            emit(
              FloorWallsLoaded(
                site,
                building,
                floor,
                _geometryRepository.roomsGeometryFor(_siteId, _floorId),
              ),
            );
            return;
          }
        }
      }
      break;
    }
    emit(const FloorWallsNotFound());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
