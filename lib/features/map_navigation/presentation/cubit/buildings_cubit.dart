import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../domain/repositories/map_geometry_repository.dart';
import 'buildings_state.dart';

class BuildingsCubit extends Cubit<BuildingsState> {
  BuildingsCubit(this._repository, this._geometryRepository, this._siteId)
    : super(const BuildingsLoading()) {
    _subscription = _repository.watchSites().listen(
      _onSitesChanged,
      onError: (Object error) => emit(BuildingsError(error.toString())),
    );
  }

  final SiteRepository _repository;
  final MapGeometryRepository _geometryRepository;
  final String _siteId;
  late final StreamSubscription<List<SiteEntity>> _subscription;

  void _onSitesChanged(List<SiteEntity> sites) {
    for (final site in sites) {
      if (site.id == _siteId) {
        emit(
          BuildingsLoaded(
            site,
            _geometryRepository.overviewGeometryFor(_siteId),
          ),
        );
        return;
      }
    }
    emit(const BuildingsNotFound());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
