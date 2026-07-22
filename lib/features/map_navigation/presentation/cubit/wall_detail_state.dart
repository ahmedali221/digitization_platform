import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/entities/wall.dart';

/// States for [WallDetailPage] — the wall itself plus the parent [SiteEntity]
/// (needed for the breadcrumb's building/floor labels).
sealed class WallDetailState extends Equatable {
  const WallDetailState();

  @override
  List<Object?> get props => [];
}

class WallDetailLoading extends WallDetailState {
  const WallDetailLoading();
}

class WallDetailLoaded extends WallDetailState {
  const WallDetailLoaded(
    this.site,
    this.buildingName,
    this.floorName,
    this.wall,
  );

  final SiteEntity site;
  final String buildingName;
  final String floorName;
  final WallEntity wall;

  @override
  List<Object?> get props => [site, buildingName, floorName, wall];
}

/// The requested site/building/floor/wall path doesn't resolve in the
/// repository.
class WallDetailNotFound extends WallDetailState {
  const WallDetailNotFound();
}

class WallDetailError extends WallDetailState {
  const WallDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
