import 'package:dio/dio.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/follow_up_package.dart';
import '../models/follow_up_upload_record.dart';

/// The dashboard's follow-up API. See its FollowUpPackageController and
/// FollowUpCaptureController.
class FollowUpRemoteDataSource {
  FollowUpRemoteDataSource(this._dio);

  final Dio _dio;

  /// The site's latest package, or null when it has none yet.
  Future<FollowUpPackage?> latestPackage(String siteId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.followUpPackage(siteId),
      );
      return FollowUpPackage.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw AppException(mapDioException(e));
    }
  }

  Future<void> downloadFile(
    String url,
    String savePath, {
    void Function(int received)? onReceived,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, _) => onReceived?.call(received),
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  /// Sends one photograph. A retry carries the same token, so the server answers
  /// it from the first upload instead of treating it as a new photograph.
  Future<void> upload(
    FollowUpUploadRecord record, {
    required Stream<List<int>> Function() openBytes,
    required int length,
  }) async {
    final isTarget = record.kind == FollowUpUploadRecord.kindTarget;
    final path = isTarget
        ? ApiEndpoints.targetImage(record.itemKey)
        : ApiEndpoints.annotationRecapture(int.parse(record.itemKey));

    try {
      await _dio.post(
        path,
        data: FormData.fromMap({
          'client_token': record.token,
          'sha256': record.sha256,
          'package_id': record.packageId,
          'captured_at': record.capturedAt.toUtc().toIso8601String(),
          if (isTarget) 'warning_confirmed': record.warningConfirmed ? '1' : '0',
          if (record.videoMatchJson != null) 'video_match': record.videoMatchJson,
          if (record.suggestedCornersJson != null)
            'suggested_corners': record.suggestedCornersJson,
          'capture': MultipartFile.fromStream(
            openBytes,
            length,
            filename: '${record.token}.jpg',
          ),
        }),
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  Future<List<Map<String, dynamic>>> results(List<String> tokens) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.followUpResults,
        data: {'tokens': tokens},
      );
      return (response.data?['results'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
