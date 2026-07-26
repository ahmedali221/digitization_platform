import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/building.dart';
import '../../../../core/domain/entities/site.dart';
import '../../domain/entities/map_geometry.dart';

/// States for [FloorsListPage] — the four feedback states required by
/// DESIGN_SYSTEM.md §8 (loading/empty/error/content). "Empty" here is a
/// property of the loaded building (zero floors), handled in the page, since
/// the building itself either resolves or it doesn't.
sealed class FloorsState extends Equatable {
  const FloorsState();

  @override
  List<Object?> get props => [];
}

class FloorsLoading extends FloorsState {
  const FloorsLoading();
}

class FloorsLoaded extends FloorsState {
  const FloorsLoaded(this.site, this.building, this.geometry);

  final SiteEntity site;
  final BuildingEntity building;

  /// Real dashboard-drawn floor positions, or null to fall back to
  /// `CanvasLayout`'s auto-grid.
  final BuildingFloorsGeometry? geometry;

  @override
  List<Object?> get props => [site, building, geometry];
}

/// The requested site/building pair doesn't resolve in the repository.
class FloorsNotFound extends FloorsState {
  const FloorsNotFound();
}

class FloorsError extends FloorsState {
  const FloorsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
