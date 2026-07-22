import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/building.dart';
import '../../../../core/domain/entities/floor.dart';
import '../../../../core/domain/entities/site.dart';

/// States for [FloorWallsPage] — the walls belonging to one floor, plus the
/// parent site and building needed by the hierarchy breadcrumb.
sealed class FloorWallsState extends Equatable {
  const FloorWallsState();

  @override
  List<Object?> get props => [];
}

class FloorWallsLoading extends FloorWallsState {
  const FloorWallsLoading();
}

class FloorWallsLoaded extends FloorWallsState {
  const FloorWallsLoaded(this.site, this.building, this.floor);

  final SiteEntity site;
  final BuildingEntity building;
  final FloorEntity floor;

  @override
  List<Object?> get props => [site, building, floor];
}

/// The requested site/building/floor path doesn't resolve in the repository.
class FloorWallsNotFound extends FloorWallsState {
  const FloorWallsNotFound();
}

class FloorWallsError extends FloorWallsState {
  const FloorWallsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
