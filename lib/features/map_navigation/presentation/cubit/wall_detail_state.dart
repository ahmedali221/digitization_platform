import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/entities/wall.dart';

/// States for [WallDetailPage] — the wall or object itself plus the parent
/// [SiteEntity] (needed for the breadcrumb's building/floor labels).
sealed class WallDetailState extends Equatable {
  const WallDetailState();

  @override
  List<Object?> get props => [];
}

class WallDetailLoading extends WallDetailState {
  const WallDetailLoading();
}

class WallDetailLoaded extends WallDetailState {
  const WallDetailLoaded({
    required this.site,
    required this.buildingName,
    required this.floorName,
    required this.wall,
    required this.hasLocalPhotos,
  });

  final SiteEntity site;
  final String buildingName;
  final String floorName;
  final WallEntity wall;

  /// This phone holds photographs of it — grid cells or object photographs,
  /// whichever way it is captured — that can be sent to the dashboard.
  final bool hasLocalPhotos;

  /// Something has been photographed already, here or as far as the last
  /// downloaded package knows, so the capture button offers more rather
  /// than a start.
  bool get hasStartedCapture =>
      hasLocalPhotos || wall.hasGrid || wall.capturedSides.isNotEmpty;

  @override
  List<Object?> get props => [
    site,
    buildingName,
    floorName,
    wall,
    hasLocalPhotos,
  ];
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
