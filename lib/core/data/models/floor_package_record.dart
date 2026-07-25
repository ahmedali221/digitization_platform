import 'package:hive/hive.dart';

import 'hive_type_ids.dart';

part 'floor_package_record.g.dart';

/// Mirrors one `floor_{id}.json` as decoded JSON (floor, canvas, rooms[],
/// wall_status_index) — see FLUTTER_MOBILE_PLAN.md §3 and `mobile map
/// plan.md`'s verified backend contract. Box [HiveBoxes.floors], keyed by
/// [floorId].
@HiveType(typeId: HiveTypeIds.floorPackageRecord)
class FloorPackageRecord extends HiveObject {
  FloorPackageRecord({
    required this.floorId,
    required this.siteId,
    required this.raw,
    required this.downloadedAt,
  });

  @HiveField(0)
  final String floorId;

  @HiveField(1)
  final String siteId;

  @HiveField(2)
  final Map<dynamic, dynamic> raw;

  @HiveField(3)
  final DateTime downloadedAt;
}
