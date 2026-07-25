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

  static const String syncUnassigned = '/sync/unassigned';
  static const String syncMappings = '/sync/mappings';
  static const String syncSessions = '/sync/sessions';
  static String syncSessionConfirm(String sessionId) =>
      '/sync/sessions/$sessionId/confirm';

  static String wallCaptures(String wallId) => '/walls/$wallId/captures';
}
