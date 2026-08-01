import 'package:dio/dio.dart';

import '../../../../core/errors/dio_failure_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_endpoints.dart';

/// Calls the two Phase 5 sync-intake endpoints — `POST /sync/unassigned`
/// (metadata registration, idempotent on `local_id`+`site_id`) and
/// `GET /sync/mappings` (resolved `local_id -> wall_id` lookup). Neither
/// endpoint accepts photo binaries — see `PROJECT_AGENT_REFERENCE.md` and
/// `FLUTTER_MOBILE_PLAN.md` §5/§8: photos stay device-local until a mapping
/// resolves, at which point they're uploaded through the existing
/// `SyncRemoteDataSource`/`/walls/{wall}/captures` pipeline instead.
class UnassignedWallRemoteDataSource {
  UnassignedWallRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> syncUnassigned({
    required String localId,
    required String siteId,
    required String deviceId,
    String? notes,
    DateTime? capturedAt,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.syncUnassigned,
        data: {
          'local_id': localId,
          'site_id': siteId,
          'device_id': deviceId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (capturedAt != null) 'captured_at': capturedAt.toIso8601String(),
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  Future<List<Map<String, dynamic>>> fetchMappings({
    required String deviceId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.syncMappings,
        queryParameters: {'device_id': deviceId},
      );
      final mappings = (response.data as Map)['mappings'] as List;
      return mappings.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
