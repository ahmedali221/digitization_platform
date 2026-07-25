import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/site.dart';

sealed class SitesState extends Equatable {
  const SitesState();

  @override
  List<Object?> get props => [];
}

class SitesLoading extends SitesState {
  const SitesLoading();
}

class SitesLoaded extends SitesState {
  const SitesLoaded({required this.sites, required this.isOffline});

  final List<SiteEntity> sites;
  final bool isOffline;

  int get readyCount => sites.where((site) => site.isReady).length;
  int get totalCount => sites.length;

  SitesLoaded copyWith({List<SiteEntity>? sites, bool? isOffline}) =>
      SitesLoaded(
        sites: sites ?? this.sites,
        isOffline: isOffline ?? this.isOffline,
      );

  @override
  List<Object?> get props => [sites, isOffline];
}

class SitesError extends SitesState {
  const SitesError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
