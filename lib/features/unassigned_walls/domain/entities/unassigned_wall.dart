import 'package:equatable/equatable.dart';

/// A wall photographed before its room/zone assignment was known — captured
/// locally under a placeholder [localId] and awaiting linkage to a real wall
/// once back online (FLUTTER_MOBILE_PLAN.md Phase 5).
enum UnassignedWallSyncStatus {
  /// Captured on-device, `POST /sync/unassigned` hasn't succeeded yet.
  notSynced,

  /// Metadata registered server-side; waiting for a dashboard operator to
  /// resolve it to a real wall (`GET /sync/mappings` hasn't matched yet).
  awaitingResolution,

  /// `GET /sync/mappings` returned a `wall_id` for this [localId] — photos
  /// can now be grid-ified and pushed through the normal capture pipeline.
  resolved,
}

class UnassignedWall extends Equatable {
  const UnassignedWall({
    required this.id,
    required this.localId,
    required this.title,
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.photoCount,
    required this.notes,
    required this.capturedAt,
    required this.syncStatus,
    this.resolvedWallId,
  });

  final String id;

  /// Placeholder identifier assigned at capture time, e.g. `local_a1b2c3d4`.
  final String localId;

  /// The title given on `AddWallPage` — e.g. "North face".
  final String title;

  final String siteId;
  final String buildingId;
  final String floorId;

  final int photoCount;
  final String notes;
  final DateTime capturedAt;
  final UnassignedWallSyncStatus syncStatus;

  /// Set once [syncStatus] is [UnassignedWallSyncStatus.resolved].
  final String? resolvedWallId;

  /// Shown as a small flag icon next to [localId] — no note has been added
  /// yet, which the dashboard operator will want before resolving this wall.
  bool get noteRequired => notes.trim().isEmpty;

  @override
  List<Object?> get props => [
    id,
    localId,
    title,
    siteId,
    buildingId,
    floorId,
    photoCount,
    notes,
    capturedAt,
    syncStatus,
    resolvedWallId,
  ];
}
