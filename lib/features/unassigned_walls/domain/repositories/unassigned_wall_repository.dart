import '../entities/unassigned_wall.dart';

/// Contract for reading walls captured before a room/zone assignment was
/// known. Linking an unassigned wall back to a real wall requires the
/// server-side resolution endpoint (out of scope for this UI-first pass —
/// see FLUTTER_MOBILE_PLAN.md Phase 5), so this is read-only for now.
abstract class UnassignedWallRepository {
  Stream<List<UnassignedWall>> watchUnassignedWalls();
}
