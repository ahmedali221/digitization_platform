import 'package:hive/hive.dart';

import 'hive_type_ids.dart';

part 'id_mapping_record.g.dart';

/// A resolved `local_id -> wall_id` mapping, pulled from `GET
/// /sync/mappings` (FLUTTER_MOBILE_PLAN.md §3/§8). Box
/// [HiveBoxes.idMappings], keyed by [localId].
@HiveType(typeId: HiveTypeIds.idMappingRecord)
class IdMappingRecord extends HiveObject {
  IdMappingRecord({
    required this.localId,
    required this.wallId,
    required this.resolvedAt,
  });

  @HiveField(0)
  final String localId;

  @HiveField(1)
  final String wallId;

  @HiveField(2)
  final DateTime resolvedAt;
}
