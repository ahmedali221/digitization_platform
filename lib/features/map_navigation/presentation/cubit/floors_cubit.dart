import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/repositories/map_geometry_repository.dart';
import 'floors_state.dart';

/// Watches one building so its floor selector stays current.
class FloorsCubit extends Cubit<FloorsState> {
  FloorsCubit(
    this._repository,
    this._geometryRepository,
    this._siteId,
    this._buildingId,
  ) : super(const FloorsLoading()) {
    _subscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(FloorsError(error.toString())),
    );
  }

  final SiteRepository _repository;
  final MapGeometryRepository _geometryRepository;
  final String _siteId;
  final String _buildingId;
  late final StreamSubscription<List<SiteEntity>> _subscription;

  void _onSitesChanged(List<SiteEntity> sites) {
    for (final site in sites) {
      if (site.id != _siteId) continue;
      for (final building in site.buildings) {
        if (building.id == _buildingId) {
          emit(
            FloorsLoaded(
              site,
              building,
              _geometryRepository.floorsGeometryFor(_siteId, _buildingId),
            ),
          );
          return;
        }
      }
      break;
    }
    emit(const FloorsNotFound());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
