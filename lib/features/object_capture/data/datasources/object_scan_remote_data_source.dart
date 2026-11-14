import 'package:dio/dio.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';

/// The server's rough model of a scan, as it reports it.
class RemoteScanPreview {
  const RemoteScanPreview({
    required this.id,
    required this.status,
    required this.progress,
    required this.hasModel,
    required this.unseenFraction,
    required this.unseen,
    required this.views,
  });

  factory RemoteScanPreview.fromJson(Map<String, dynamic> json) {
    return RemoteScanPreview(
      id: json['id'] as int,
      status: json['status'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      hasModel: json['model_url'] != null,
      unseenFraction: (json['unseen_fraction'] as num?)?.toDouble(),
      unseen: [
        for (final side in (json['unseen'] as List?) ?? const [])
          (
            azimuth: ((side as Map)['azimuth'] as num).toDouble(),
            elevation: (side['elevation'] as num).toDouble(),
          ),
      ],
      views: [
        for (final view in (json['views'] as List?) ?? const [])
          (
            sequence: RemoteScanState.sequenceOf(
              (view as Map)['name'] as String,
            ),
            azimuth: (view['azimuth'] as num).toDouble(),
          ),
      ],
    );
  }

  /// The server's id of the run that built it.
  final int id;
  final String status;
  final double progress;
  final bool hasModel;
  final double? unseenFraction;

  /// The sides of the object no photograph showed, in the server's angles.
  final List<({double azimuth, double elevation})> unseen;

  /// Where the server found each photograph to be taken from, in the same
  /// angles, by the photograph's server number.
  final List<({int? sequence, double azimuth})> views;
}

/// What the server says about a scan (`ObjectScanController` on the
/// dashboard), reduced to what this app uses.
class RemoteScanState {
  const RemoteScanState({
    required this.id,
    required this.status,
    required this.reasons,
    required this.gaps,
    required this.unusable,
    required this.isWholeScanUnusable,
    required this.failureReason,
    required this.runProgress,
    required this.preview,
  });

  factory RemoteScanState.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>?;
    final run = json['run'] as Map<String, dynamic>?;
    final preview = json['preview'] as Map<String, dynamic>?;
    return RemoteScanState(
      id: json['id'] as int,
      status: json['status'] as String,
      reasons: [...?(coverage?['reasons'] as List?)?.cast<String>()],
      gaps: [
        for (final gap in (coverage?['gaps'] as List?) ?? const [])
          (
            from: ((gap as Map)['from_degrees'] as num).toDouble(),
            to: (gap['to_degrees'] as num).toDouble(),
          ),
      ],
      unusable: [
        ...(coverage?['unplaced_photos'] as List?) ?? const [],
        ...(coverage?['photos_set_aside'] as Map?)?.keys ?? const [],
      ].map((name) => sequenceOf(name as String)).nonNulls.toList(),
      isWholeScanUnusable: coverage?['verdict'] == 'failed',
      failureReason: json['failure_reason'] as String?,
      runProgress: (run?['progress'] as num?)?.toDouble() ?? 0,
      preview: preview == null ? null : RemoteScanPreview.fromJson(preview),
    );
  }

  final int id;
  final String status;
  final List<String> reasons;
  final List<({double from, double to})> gaps;

  /// Server numbers of the photographs it made nothing of: those it could
  /// not fit to the rest, and those it set aside as blurred or too dark.
  final List<int> unusable;

  /// Fewer than half the photographs fitted together. The ones that did are
  /// not a start worth building on: the scan is shot again from nothing.
  final bool isWholeScanUnusable;
  final String? failureReason;
  final double runProgress;

  /// Null when the server has no rough model of the scan as it stands.
  final RemoteScanPreview? preview;

  /// The server names a photograph by its number, as in `0007.jpg`.
  static int? sequenceOf(String photoName) =>
      int.tryParse(photoName.split('.').first);
}

/// Dio calls for a 3D scan: start it on the object, one upload per
/// photograph, then one call saying which photographs the phone holds.
class ObjectScanRemoteDataSource {
  ObjectScanRemoteDataSource(this._dio);

  final Dio _dio;

  /// Safe to repeat: the server knows a scan by [clientUuid].
  Future<RemoteScanState> start({
    required String wallId,
    required String clientUuid,
    required bool fullCircle,
  }) {
    return _state(
      () => _dio.post(
        ApiEndpoints.wallScans(wallId),
        data: {
          'client_uuid': clientUuid,
          'hints': {'full_circle': fullCircle},
        },
      ),
    );
  }

  /// Returns the number the server knows the photograph by. Safe to repeat:
  /// the server recognises a photograph by its checksum.
  Future<int> uploadPhoto({
    required int scanId,
    required Stream<List<int>> Function() openImageBytes,
    required int imageLength,
    required String fileName,
    required String sha256,
    required DateTime capturedAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.scanPhotos(scanId),
        data: FormData.fromMap({
          'sha256': sha256,
          'captured_at': capturedAt.toUtc().toIso8601String(),
          'photo': MultipartFile.fromStream(
            openImageBytes,
            imageLength,
            filename: fileName,
          ),
        }),
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );
      return response.data!['sequence'] as int;
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  /// Returns only if the server holds a photograph for every checksum;
  /// otherwise it answers 422 and the upload is retried.
  Future<RemoteScanState> complete({
    required int scanId,
    required List<String> checksums,
  }) {
    return _state(
      () => _dio.post(
        ApiEndpoints.scanComplete(scanId),
        data: {'checksums': checksums},
      ),
    );
  }

  Future<RemoteScanState> fetch(int scanId) =>
      _state(() => _dio.get(ApiEndpoints.scan(scanId)));

  /// Saves the scan's rough model to [savePath].
  Future<void> downloadPreview({
    required int scanId,
    required String savePath,
  }) async {
    try {
      await _dio.download(ApiEndpoints.scanPreview(scanId), savePath);
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  Future<RemoteScanState> _state(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      return RemoteScanState.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
