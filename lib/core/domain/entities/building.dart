import 'package:equatable/equatable.dart';

import '../../theme/wall_status.dart';
import 'floor.dart';

/// A physical building or archaeological structure within a site.
///
/// Buildings own floors; walls are never attached directly to a building.
class BuildingEntity extends Equatable {
  const BuildingEntity({
    required this.id,
    required this.siteId,
    required this.name,
    required this.floors,
  });

  final String id;
  final String siteId;
  final String name;
  final List<FloorEntity> floors;

  int get wallCount =>
      floors.fold(0, (count, floor) => count + floor.walls.length);

  int get doneCount =>
      floors.fold(0, (count, floor) => count + floor.doneCount);

  WallStatus get aggregateStatus => aggregateWallStatus(
    floors.expand((floor) => floor.walls).map((wall) => wall.status).toList(),
  );

  BuildingEntity copyWithFloors(List<FloorEntity> floors) {
    return BuildingEntity(id: id, siteId: siteId, name: name, floors: floors);
  }

  @override
  List<Object?> get props => [id, siteId, name, floors];
}
