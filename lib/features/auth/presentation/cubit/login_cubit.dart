import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginIdle());

  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) async {
    emit(const LoginSubmitting());
    try {
      await _repository.login(email: email, password: password);
      emit(const LoginSuccess());
    } on AppException catch (e) {
      emit(LoginFailure(e.failure.message));
    } catch (e) {
      emit(LoginFailure(e.toString()));
    }
  }
}
