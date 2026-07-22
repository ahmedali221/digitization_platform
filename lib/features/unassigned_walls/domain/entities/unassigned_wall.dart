import 'package:equatable/equatable.dart';

/// A wall photographed before its room/zone assignment was known — captured
/// locally under a placeholder [localId] and awaiting linkage to a real wall
/// once back online (FLUTTER_MOBILE_PLAN.md Phase 5).
class UnassignedWall extends Equatable {
  const UnassignedWall({
    required this.id,
    required this.localId,
    required this.photoCount,
    required this.noteRequired,
  });

  final String id;

  /// Placeholder identifier assigned at capture time, e.g. `LOCAL-014`.
  final String localId;

  final int photoCount;

  /// Whether the operator flagged this capture as needing a note before it
  /// can be linked (shown as a small flag icon next to [localId]).
  final bool noteRequired;

  @override
  List<Object?> get props => [id, localId, photoCount, noteRequired];
}
