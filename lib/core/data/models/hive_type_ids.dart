/// Central Hive `typeId` registry. Hive requires every `@HiveType` id to be
/// unique across the whole app, so every adapter's id is assigned here,
/// once, rather than picked ad hoc per file.
class HiveTypeIds {
  const HiveTypeIds._();

  static const int sitePackageRecord = 0;
  static const int floorPackageRecord = 1;
  static const int wallStatusRecord = 2;
  static const int idMappingRecord = 3;
  static const int captureSessionRecord = 4;
  static const int captureCellRecord = 5;
  static const int capturePhotoRecord = 6;
  static const int syncQueueItemRecord = 7;
}
