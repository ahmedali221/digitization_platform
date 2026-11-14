import 'package:equatable/equatable.dart';

import '../../theme/wall_status.dart';
import 'hall.dart';
import 'wall.dart';

/// A floor within a building. Its [walls] are shown only after the user has
/// selected both the parent building and this floor.
class FloorEntity extends Equatable {
  const FloorEntity({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.walls,
    this.halls = const [],
  });

  final String id;
  final String buildingId;
  final String name;

  /// Every wall and object on the floor, whatever its type.
  final List<WallEntity> walls;

  /// The chambers or halls a new item can be filed under.
  final List<HallEntity> halls;

  WallStatus get aggregateStatus =>
      aggregateWallStatus(walls.map((w) => w.status).toList());

  int get doneCount => walls
      .where(
        (w) => w.status == WallStatus.done || w.status == WallStatus.captured,
      )
      .length;

  FloorEntity copyWith({List<WallEntity>? walls, List<HallEntity>? halls}) {
    return FloorEntity(
      id: id,
      buildingId: buildingId,
      name: name,
      walls: walls ?? this.walls,
      halls: halls ?? this.halls,
    );
  }

  @override
  List<Object?> get props => [id, buildingId, name, walls, halls];
}
