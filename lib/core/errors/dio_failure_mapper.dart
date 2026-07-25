import 'package:dio/dio.dart';

import 'failure.dart';

/// Pure `DioException -> Failure` mapping, used by every remote data source
/// so error-shape parsing lives in exactly one place.
Failure mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return _mapResponse(exception);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
    default:
      return const UnknownFailure();
  }
}

Failure _mapResponse(DioException exception) {
  final response = exception.response;
  final statusCode = response?.statusCode;
  final data = response?.data;
  final message = (data is Map && data['message'] is String)
      ? data['message'] as String
      : exception.message ?? 'Request failed.';

  if (statusCode == 401) {
    return UnauthorizedFailure(message);
  }

  if (statusCode == 422 && data is Map && data['errors'] is Map) {
    final rawErrors = data['errors'] as Map;
    final errors = <String, List<String>>{
      for (final entry in rawErrors.entries)
        entry.key as String: List<String>.from(entry.value as List),
    };
    return ValidationFailure(message, errors);
  }

  return ServerFailure(statusCode, message);
}
