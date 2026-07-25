import '../../../../core/network/session_notifier.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureTokenStorage tokenStorage,
  }) : _remote = remote,
       _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;

  @override
  Future<void> login({required String email, required String password}) async {
    final token = await _remote.login(email: email, password: password);
    await _tokenStorage.saveToken(token);
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
    final hasSession = token != null;
    isLoggedInNotifier.value = hasSession;
    return hasSession;
  }
}
