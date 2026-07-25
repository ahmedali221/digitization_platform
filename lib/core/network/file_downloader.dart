import 'dart:io';

import 'package:dio/dio.dart';

/// Wraps `Dio.download()` with a resumable-on-failure skip check. Today's
/// package manifest carries no per-file checksum (only `SitePackageVersion`
/// has one overall `files_json` map of URLs) — so "already downloaded,
/// skip" is approximated by comparing the local file's size against the
/// remote `Content-Length`, not a true hash comparison. True per-file
/// hash-diffing needs a dashboard contract change and is out of scope here.
class FileDownloader {
  FileDownloader(this._dio);

  final Dio _dio;

  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final file = File(savePath);
    if (await file.exists()) {
      final remoteSize = await _remoteContentLength(url);
      final localSize = await file.length();
      if (remoteSize != null && remoteSize == localSize) {
        onProgress?.call(localSize, localSize);
        return;
      }
    }

    await _dio.download(url, savePath, onReceiveProgress: onProgress);
  }

  Future<int?> _remoteContentLength(String url) async {
    try {
      final response = await _dio.head(url);
      final contentLength = response.headers.value(Headers.contentLengthHeader);
      return contentLength != null ? int.tryParse(contentLength) : null;
    } on DioException {
      return null;
    }
  }
}
