import 'package:equatable/equatable.dart';

import '../../theme/wall_status.dart';
import 'wall.dart';

/// A floor within a building. Its [walls] are shown only after the user has
/// selected both the parent building and this floor.
class FloorEntity extends Equatable {
  const FloorEntity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.walls,
  });

  final String id;
  final String buildingId;
  final String name;
  final List<WallEntity> walls;

  WallStatus get aggregateStatus =>
      aggregateWallStatus(walls.map((w) => w.status).toList());

  int get doneCount => walls
      .where(
        (w) => w.status == WallStatus.done || w.status == WallStatus.captured,
      )
      .length;

  FloorEntity copyWithWalls(List<WallEntity> walls) {
    return FloorEntity(
      id: id,
      buildingId: buildingId,
      name: name,
      walls: walls,
    );
  }

  @override
  List<Object?> get props => [id, buildingId, name, walls];
}
