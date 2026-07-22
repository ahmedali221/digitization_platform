import '../../domain/entities/unassigned_wall.dart';
import '../../domain/repositories/unassigned_wall_repository.dart';

/// In-memory stand-in for the real Hive/Dio-backed repository, seeded with
/// the exact mock data from the Claude Design handoff prototype
/// (`design-system-documentation/project/WallBase Sites.dc.html`).
class FakeUnassignedWallRepository implements UnassignedWallRepository {
  static const _seed = [
    UnassignedWall(
      id: 'u1',
      localId: 'LOCAL-014',
      photoCount: 6,
      noteRequired: true,
    ),
    UnassignedWall(
      id: 'u2',
      localId: 'LOCAL-015',
      photoCount: 3,
      noteRequired: false,
    ),
  ];

  @override
  Stream<List<UnassignedWall>> watchUnassignedWalls() async* {
    yield _seed;
  }
}
