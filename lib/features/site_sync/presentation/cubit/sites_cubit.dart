import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/network/connectivity_observer.dart';
import 'sites_state.dart';

/// Drives the sites list screen.
class SitesCubit extends Cubit<SitesState> {
  SitesCubit(this._repository, this._connectivity)
    : super(const SitesLoading()) {
    _subscribe();
    // Best-effort: populates the catalog on first launch / picks up newly
    // published sites. Failure (e.g. offline) just leaves whatever's
    // already cached — watchSites() already reflects that.
    unawaited(_repository.refreshCatalog());
  }

  final SiteRepository _repository;
  final ConnectivityObserver _connectivity;
  StreamSubscription<List<SiteEntity>>? _sitesSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOffline = false;

  void _subscribe() {
    _sitesSubscription?.cancel();
    _sitesSubscription = _repository.watchSites().listen(
      (sites) => emit(SitesLoaded(sites: sites, isOffline: _isOffline)),
      onError: (Object error) => emit(SitesError(error.toString())),
    );

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      connected,
    ) {
      _isOffline = !connected;
      final current = state;
      if (current is SitesLoaded) {
        emit(current.copyWith(isOffline: _isOffline));
      }
    });
  }

  /// Re-subscribes to the repository stream. Wired to the error state's
  /// Retry action.
  void retry() {
    emit(const SitesLoading());
    _subscribe();
  }

  Future<void> refreshCatalog() => _repository.refreshCatalog();

  Future<({int fileCount, int totalBytes})> estimateDownload(String siteId) =>
      _repository.estimateDownload(siteId);

  Future<void> startDownload(String siteId) =>
      _repository.startDownload(siteId);

  Future<void> deleteCachedSite(String siteId) =>
      _repository.deleteCachedSite(siteId);

  @override
  Future<void> close() {
    _sitesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
