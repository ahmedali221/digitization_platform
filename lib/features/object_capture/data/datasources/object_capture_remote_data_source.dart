import 'package:dio/dio.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';

/// Dio calls for an object's photographs (`ObjectPhotoController` on the
/// dashboard): one upload per photo, then one call saying which photos the
/// phone holds, which the server answers only once it holds them all.
class ObjectCaptureRemoteDataSource {
  ObjectCaptureRemoteDataSource(this._dio);

  final Dio _dio;

  /// Safe to repeat: the server recognises a photo it already has by its
  /// checksum and only refreshes that photo's side and comment.
  Future<void> uploadPhoto({
    required String wallId,
    required Stream<List<int>> Function() openImageBytes,
    required int imageLength,
    required String fileName,
    required String sha256,
    required DateTime capturedAt,
    String? side,
    String? comment,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.wallObjectPhotos(wallId),
        data: FormData.fromMap(
          <String, dynamic>{
            'sha256': sha256,
            'captured_at': capturedAt.toUtc().toIso8601String(),
            'side': side,
            'comment': (comment ?? '').isEmpty ? null : comment,
            'photo': MultipartFile.fromStream(
              openImageBytes,
              imageLength,
              filename: fileName,
            ),
          }..removeWhere((_, value) => value == null),
        ),
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  /// Returns only if the server holds a photo for every checksum; otherwise
  /// it answers 422 and the upload is retried rather than treated as done.
  Future<void> complete({
    required String wallId,
    required List<String> checksums,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.wallObjectPhotosComplete(wallId),
        data: {'checksums': checksums},
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
