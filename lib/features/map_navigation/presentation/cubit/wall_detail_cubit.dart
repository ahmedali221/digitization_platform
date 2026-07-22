import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import 'wall_detail_state.dart';

/// Watches the repository's site tree and derives the [siteId] building,
/// [floorId] floor's name, and the [wallId] wall itself, so [WallDetailPage]
/// reflects status/grid changes live once a capture session writes back.
class WallDetailCubit extends Cubit<WallDetailState> {
  WallDetailCubit(
    this._repository,
    this._siteId,
    this._buildingId,
    this._floorId,
    this._wallId,
  ) : super(const WallDetailLoading()) {
    _subscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(WallDetailError(error.toString())),
    );
  }

  final SiteRepository _repository;
  final String _siteId;
  final String _buildingId;
  final String _floorId;
  final String _wallId;
  late final StreamSubscription<List<SiteEntity>> _subscription;

  void _onSitesChanged(List<SiteEntity> sites) {
    for (final site in sites) {
      if (site.id != _siteId) continue;
      for (final building in site.buildings) {
        if (building.id != _buildingId) continue;
        for (final floor in building.floors) {
          if (floor.id != _floorId) continue;
          for (final wall in floor.walls) {
            if (wall.id == _wallId) {
              emit(WallDetailLoaded(site, building.name, floor.name, wall));
              return;
            }
          }
        }
      }
      break;
    }
    emit(const WallDetailNotFound());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
