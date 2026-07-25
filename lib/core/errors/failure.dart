import 'package:equatable/equatable.dart';

/// Typed failures repositories throw (wrapped in [AppException]), matching
/// the API contract's documented error shapes and retry guidance: network
/// failures and 5xx are retryable, a 422 validation failure should not be
/// retried as-is but surfaced for the user to correct.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection to the server.']);
}

class ServerFailure extends Failure {
  const ServerFailure(this.statusCode, super.message);

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// Mirrors the documented `{"message": "...", "errors": {"field": [...]}}`
/// shape returned on a 422.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, this.errors);

  final Map<String, List<String>> errors;

  @override
  List<Object?> get props => [message, errors];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}

/// Thin exception wrapper so a [Failure] can be thrown/caught through
/// layers that expect an [Exception], without repositories inventing their
/// own per-feature exception types.
class AppException implements Exception {
  const AppException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.message;
}
