import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  /// `device_name` is a plain descriptive constant, not a real device
  /// fingerprint — this is a single-operator app with a handful of
  /// devices, not something needing a dedicated device-info package.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.tokens,
        data: {
          'email': email,
          'password': password,
          'device_name': 'wallbase-mobile-${Platform.operatingSystem}',
        },
      );
      return response.data['token'] as String;
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
