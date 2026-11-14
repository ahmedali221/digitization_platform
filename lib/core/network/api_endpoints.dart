/// Path constants for `dashboard/routes/api.php`, kept in one place so a
/// route rename on either side is a one-file diff here.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String tokens = '/tokens';
  static const String me = '/me';
  static const String sites = '/sites';

  static String sitePackage(String siteId) => '/sites/$siteId/package';
  static String sitePublishStatus(String siteId) =>
      '/sites/$siteId/publish-status';

  static String floorItems(String floorId) => '/floors/$floorId/items';

  static const String syncSessions = '/sync/sessions';
  static String syncSessionConfirm(String sessionId) =>
      '/sync/sessions/$sessionId/confirm';

  static String wallCaptures(String wallId) => '/walls/$wallId/captures';
  static String wallObjectPhotos(String wallId) =>
      '/walls/$wallId/object-photos';
  static String wallObjectPhotosComplete(String wallId) =>
      '/walls/$wallId/object-photos/complete';

  static String wallScans(String wallId) => '/walls/$wallId/scans';
  static String scan(int scanId) => '/scans/$scanId';
  static String scanPhotos(int scanId) => '/scans/$scanId/photos';
  static String scanComplete(int scanId) => '/scans/$scanId/complete';
  static String scanPreview(int scanId) => '/scans/$scanId/preview';

  static String followUpPackage(String siteId) =>
      '/sites/$siteId/follow-up-package';
  static String annotationRecapture(int annotationId) =>
      '/annotations/$annotationId/recapture';
  static String targetImage(String arKey) => '/studio-assets/$arKey/image';
  static String targetWidth(String arKey) =>
      '/studio-assets/$arKey/physical-width';
  static String newTargets(String siteId) => '/sites/$siteId/new-targets';
  static const String followUpResults = '/follow-up/results';
  static String recaptureGrids(int annotationId) =>
      '/annotations/$annotationId/recapture-grids';
  static String recaptureGridTiles(String token) =>
      '/recapture-grids/$token/tiles';
  static String recaptureGridDecision(String token) =>
      '/recapture-grids/$token/decision';
  static String recaptureGridPreview(String token) =>
      '/recapture-grids/$token/preview';
}
