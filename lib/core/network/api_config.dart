/// Dashboard base URL. Defaults to the real deployed WallBase dashboard;
/// override at build/run time for a different environment (e.g. local dev):
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://digital.niletechdev.com',
  );

  static const String apiPrefix = '$baseUrl/api';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Photo uploads can be large (up to 50MB each, per the API contract) and
  /// slow on field connectivity — a longer send timeout than the default.
  static const Duration uploadSendTimeout = Duration(minutes: 5);
}
