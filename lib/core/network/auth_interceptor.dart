import 'package:dio/dio.dart';

import '../storage/secure_token_storage.dart';
import 'session_notifier.dart';

/// Attaches the stored bearer token to every request. On a real 401 from
/// the server (revoked/invalid token), clears the session — but a
/// network/timeout error must NOT clear it, since a field operator with no
/// signal has to stay logged in against locally cached data (see
/// AuthRepositoryImpl.hasValidSession, which is a local-only check for the
/// same reason).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final SecureTokenStorage _tokenStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _tokenStorage.clearToken();
      isLoggedInNotifier.value = false;
    }
    handler.next(err);
  }
}
