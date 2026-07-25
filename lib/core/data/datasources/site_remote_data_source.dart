import 'package:dio/dio.dart';

import '../../errors/dio_failure_mapper.dart';
import '../../errors/failure.dart';
import '../../network/api_endpoints.dart';

/// One entry from `GET /sites` — catalog metadata only, no bundle content.
class SiteSummary {
  const SiteSummary({
    required this.id,
    required this.name,
    required this.location,
    required this.latestVersion,
    required this.latestStatus,
    required this.latestPublishedAt,
  });

  factory SiteSummary.fromJson(Map<String, dynamic> json) {
    final latestPackage = json['latest_package'] as Map<String, dynamic>?;
    return SiteSummary(
      id: json['id'].toString(),
      name: json['name'] as String,
      location: json['location'] as String?,
      latestVersion: latestPackage?['version'] as int?,
      latestStatus: latestPackage?['status'] as String?,
      latestPublishedAt: latestPackage?['published_at'] != null
          ? DateTime.parse(latestPackage!['published_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String? location;
  final int? latestVersion;
  final String? latestStatus;
  final DateTime? latestPublishedAt;

  bool get hasPublishedPackage => latestStatus == 'done';
}

/// One file entry from `GET /sites/{id}/package`'s `files` map.
class PackageManifest {
  const PackageManifest({
    required this.version,
    required this.publishedAt,
    required this.files,
  });

  factory PackageManifest.fromJson(Map<String, dynamic> json) {
    return PackageManifest(
      version: json['version'] as int,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      files: Map<String, String>.from(json['files'] as Map),
    );
  }

  final int version;
  final DateTime? publishedAt;

  /// File key (e.g. `site_package`, `floor_7`) -> signed/direct URL.
  final Map<String, String> files;
}

class SiteRemoteDataSource {
  SiteRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<SiteSummary>> fetchSiteSummaries() async {
    try {
      final response = await _dio.get(ApiEndpoints.sites);
      final sites = (response.data['sites'] as List)
          .cast<Map<String, dynamic>>();
      return sites.map(SiteSummary.fromJson).toList();
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }

  Future<PackageManifest> fetchPackageManifest(String siteId) async {
    try {
      final response = await _dio.get(ApiEndpoints.sitePackage(siteId));
      return PackageManifest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException(mapDioException(e));
    }
  }
}
