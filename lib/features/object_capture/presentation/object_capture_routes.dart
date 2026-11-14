/// The paths of the object capture screens for one object, so the screens
/// and the router agree on them without each rebuilding the same string.
class ObjectCaptureRoutes {
  const ObjectCaptureRoutes({
    required this.siteId,
    required this.buildingId,
    required this.floorId,
    required this.wallId,
  });

  static const modesSegment = 'object-capture';
  static const organisedSegment = 'organised';
  static const freeSegment = 'free';
  static const scanSegment = 'scan';
  static const scanStatusSegment = 'scan-status';

  final String siteId;
  final String buildingId;
  final String floorId;
  final String wallId;

  /// The object's own page, which every capture screen returns to.
  String get wall =>
      '/sites/$siteId/buildings/$buildingId/floors/$floorId/walls/$wallId';

  String get modes => '$wall/$modesSegment';
  String get organised => '$modes/$organisedSegment';
  String get free => '$modes/$freeSegment';
  String get scan => '$modes/$scanSegment';
  String get scanStatus => '$modes/$scanStatusSegment';
}
