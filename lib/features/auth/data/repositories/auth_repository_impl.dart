import '../../../../core/network/session_notifier.dart';
import '../../../../core/storage/device_id_provider.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureTokenStorage tokenStorage,
    required DeviceIdProvider deviceIdProvider,
  }) : _remote = remote,
       _tokenStorage = tokenStorage,
       _deviceIdProvider = deviceIdProvider;

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;
  final DeviceIdProvider _deviceIdProvider;

  @override
  Future<void> login({required String email, required String password}) async {
    final token = await _remote.login(email: email, password: password);
    await _tokenStorage.saveToken(token);
    await _deviceIdProvider.getOrCreateDeviceId();
    isLoggedInNotifier.value = true;
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clearToken();
    isLoggedInNotifier.value = false;
  }

  @override
  Future<bool> hasValidSession() async {
    final token = await _tokenStorage.readToken();
    // On iOS, a Keychain-backed token can outlive a true app reinstall even
    // though the sandboxed Documents directory (every Hive box) comes back
    // empty — see DeviceIdProvider.hasExistingDeviceId. Treat that mismatch
    // as no session, rather than reporting "logged in" over data that's
    // silently gone, and drop the now-orphaned token.
    if (token != null && !_deviceIdProvider.hasExistingDeviceId()) {
      await _tokenStorage.clearToken();
      isLoggedInNotifier.value = false;
      return false;
    }
    final hasSession = token != null;
    isLoggedInNotifier.value = hasSession;
    return hasSession;
  }
}
