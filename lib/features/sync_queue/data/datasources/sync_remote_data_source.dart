import 'package:dio/dio.dart';

import '../../../../core/domain/entities/object_type.dart';
import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../grid_capture/data/models/capture_session_record.dart';
import '../../domain/entities/field_item_registration.dart';

/// Dio calls for creating a field item (`FieldItemController`) and for the
/// three grid sync endpoints (`SyncController`/`CaptureController`). Photo
/// binaries upload separately from the manifest registration, per the
/// documented contract.
class SyncRemoteDataSource {
  SyncRemoteDataSource(this._dio);

  final Dio _dio;

  /// Creates a wall or object this phone made offline. Idempotent on the
  /// payload's `client_uuid`: a retry returns the wall the first call made.
  Future<FieldItemRegistration> createFieldItem({
    required String floorId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.floorItems(floorId),
        data: payload,
      );
      final body = (response.data as Map).cast<String, dynamic>();
      return FieldItemRegistration(
        serverWallId: body['wall_id'].toString(),
        createdAt:
            DateTime.tryParse(body['created_at'] as String? ?? '') ??
            DateTime.now(),
        hallId: body['chamber_id']?.toString(),
        hallName: body['chamber_name'] as String?,
        intakeStatus: IntakeStatus.fromWire(body['intake_status'] as String?),
        isArchived: body['is_archived'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  /// Registers the grid + checksum manifest; returns the server-assigned
  /// session id used to confirm later.
  Future<String> registerSession({
    required String deviceId,
    required String siteId,
    required String wallId,
    required CaptureSessionRecord session,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.syncSessions,
        data: {
          'device_id': deviceId,
          'site_id': siteId,
          'wall_id': wallId,
          'grid_rows': session.gridRows,
          'grid_cols': session.gridCols,
          'cells': session.cells
              .map(
                (cell) => {
                  'row': cell.row,
                  'col': cell.col,
                  'photos': cell.photos
                      .map(
                        (p) => {'file': _fileName(p.file), 'sha256': p.sha256},
                      )
                      .toList(),
                },
              )
              .where((cell) => (cell['photos'] as List).isNotEmpty)
              .toList(),
        },
      );
      return response.data['id'].toString();
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  /// One multipart upload per photo — `shot` is a single optional field on
  /// the endpoint, so a 1:1 call keeps the mapping unambiguous rather than
  /// guessing how multiple files in one call would map to shot numbers.
  Future<void> uploadCellPhoto({
    required String wallId,
    required int row,
    required int col,
    required int shot,
    required Stream<List<int>> Function() openImageBytes,
    required int imageLength,
    required String fileName,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.wallCaptures(wallId),
        data: FormData.fromMap({
          'row': row,
          'col': col,
          'shot': shot,
          'photos[]': MultipartFile.fromStream(
            openImageBytes,
            imageLength,
            filename: fileName,
          ),
        }),
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  Future<void> confirmSession(String serverSessionId) async {
    try {
      await _dio.post(ApiEndpoints.syncSessionConfirm(serverSessionId));
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;
}
