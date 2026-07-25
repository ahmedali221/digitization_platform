import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for the one thing that must
/// never live in Hive (plaintext-on-disk) or SharedPreferences: the Sanctum
/// bearer token.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'wallbase.auth_token';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(
    key: _tokenKey,
    value: token,
  );

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
