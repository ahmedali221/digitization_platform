import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One readable line per request and per response/error, so every dashboard
/// call — site download, wall photo upload, sync confirm — is visible in the
/// debug console as it happens. Bodies are truncated and binary payloads
/// (downloaded images/JSON bytes) are reported by length only, so a large
/// photo upload or package download doesn't flood the console. Registered
/// only in [kDebugMode] (see `buildApiClient`) — never runs in release.
class ApiLoggingInterceptor extends Interceptor {
  static const _maxBodyLength = 2000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['requestStartedAt'] = DateTime.now();
    debugPrint(
      '→ ${options.method} ${options.uri}\n'
      '   headers: ${_redactHeaders(options.headers)}\n'
      '   body: ${_describeBody(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri} (${_elapsed(response.requestOptions)})\n'
      '   body: ${_describeBody(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '✕ ${err.response?.statusCode ?? '—'} ${err.requestOptions.method} '
      '${err.requestOptions.uri} (${_elapsed(err.requestOptions)})\n'
      '   ${err.type}: ${err.message}\n'
      '   body: ${_describeBody(err.response?.data)}',
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final startedAt = options.extra['requestStartedAt'];
    if (startedAt is! DateTime) return '?ms';
    return '${DateTime.now().difference(startedAt).inMilliseconds}ms';
  }

  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final redacted = Map<String, dynamic>.from(headers);
    final auth = redacted['Authorization'];
    if (auth is String && auth.length > 12) {
      redacted['Authorization'] = '${auth.substring(0, 12)}…';
    }
    return redacted;
  }

  String _describeBody(Object? data) {
    if (data == null) return '(none)';
    if (data is FormData) {
      final fields = data.fields.map((f) => '${f.key}=${f.value}').join(', ');
      final files = data.files
          .map((f) => '${f.key}=${f.value.filename} (${f.value.length}B)')
          .join(', ');
      return 'FormData{fields: [$fields], files: [$files]}';
    }
    if (data is List<int>) return '<binary ${data.length}B>';

    final text = data is String ? data : _tryEncode(data);
    return text.length > _maxBodyLength
        ? '${text.substring(0, _maxBodyLength)}… (${text.length} chars total)'
        : text;
  }

  String _tryEncode(Object data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
