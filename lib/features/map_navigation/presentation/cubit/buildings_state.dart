import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/site.dart';
import '../../domain/entities/map_geometry.dart';

sealed class BuildingsState extends Equatable {
  const BuildingsState();

  @override
  List<Object?> get props => [];
}

class BuildingsLoading extends BuildingsState {
  const BuildingsLoading();
}

class BuildingsLoaded extends BuildingsState {
  const BuildingsLoaded(this.site, this.geometry);

  final SiteEntity site;

  /// Real dashboard-drawn building positions, or null to fall back to
  /// `CanvasLayout`'s auto-grid.
  final SiteOverviewGeometry? geometry;

  @override
  List<Object?> get props => [site, geometry];
}

class BuildingsNotFound extends BuildingsState {
  const BuildingsNotFound();
}

class BuildingsError extends BuildingsState {
  const BuildingsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
