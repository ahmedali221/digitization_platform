import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';

/// Builds the single [Dio] instance the app uses for every dashboard call.
/// Registered as a lazy singleton in the DI container — repositories depend
/// on `Dio`, never construct their own.
Dio buildApiClient(AuthInterceptor authInterceptor) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.apiPrefix,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(authInterceptor);

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }

  return dio;
}
