import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import 'sites_state.dart';

/// Drives the sites list screen. `isOffline` is hardcoded to `false` for now
/// — Phase 7 wires `connectivity_plus` and will replace this with a real
/// connectivity stream instead of a constant.
class SitesCubit extends Cubit<SitesState> {
  SitesCubit(this._repository) : super(const SitesLoading()) {
    _subscribe();
  }

  static const bool _isOffline = false;

  final SiteRepository _repository;
  StreamSubscription<List<SiteEntity>>? _subscription;

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchSites().listen(
      (sites) => emit(SitesLoaded(sites: sites, isOffline: _isOffline)),
      onError: (Object error) => emit(SitesError(error.toString())),
    );
  }

  /// Re-subscribes to the repository stream. Wired to the error state's
  /// Retry action.
  void retry() {
    emit(const SitesLoading());
    _subscribe();
  }

  Future<void> startDownload(String siteId) =>
      _repository.startDownload(siteId);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
