import 'package:hive/hive.dart';

import 'hive_type_ids.dart';

part 'wall_status_record.g.dart';

/// The local source of truth for wall status (FLUTTER_MOBILE_PLAN.md §4) —
/// never re-derived from a downloaded bundle once it exists locally. Box
/// [HiveBoxes.wallStatus], keyed by [wallId].
///
/// [status] is stored as the `WallStatus` enum's name (e.g. "inProgress")
/// rather than via a second Hive adapter, so the enum defined once in
/// `core/theme/wall_status.dart` stays the single source of truth for valid
/// values — the mapper converts at the read boundary.
@HiveType(typeId: HiveTypeIds.wallStatusRecord)
class WallStatusRecord extends HiveObject {
  WallStatusRecord({
    required this.wallId,
    required this.status,
    required this.dirty,
    required this.updatedAt,
  });

  @HiveField(0)
  final String wallId;

  @HiveField(1)
  final String status;

  @HiveField(2)
  final bool dirty;

  @HiveField(3)
  final DateTime updatedAt;
}
