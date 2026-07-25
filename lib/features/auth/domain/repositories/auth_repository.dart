/// Bootstraps and holds the device's Sanctum bearer token. Deliberately
/// minimal — this is a single-operator app, not multi-account management.
abstract class AuthRepository {
  Future<void> login({required String email, required String password});

  Future<void> logout();

  /// Local-only check (reads secure storage, no network call) — so the app
  /// opens straight past the login screen on every relaunch, online or
  /// offline, once logged in once. See AuthInterceptor for the
  /// corresponding rule on when a session actually ends.
  Future<bool> hasValidSession();
}
