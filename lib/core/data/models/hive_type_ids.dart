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
  // 8 belonged to the unassigned-walls record. Not to be reused: a phone
  // updated from an older build may still hold a box written with it.
  static const int cellQualityRecord = 9;
  static const int neighbourQualityRecord = 10;
  static const int shotQualityScoreRecord = 11;
  static const int followUpUploadRecord = 12;
  static const int objectCaptureRecord = 13;
  static const int objectPhotoRecord = 14;
  static const int objectScanRecord = 15;
  static const int scanShotRecord = 16;
}
