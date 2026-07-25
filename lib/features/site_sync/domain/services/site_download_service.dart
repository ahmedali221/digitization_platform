import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/data/datasources/site_local_data_source.dart';
import '../../../../core/data/datasources/site_remote_data_source.dart';
import '../../../../core/data/models/floor_package_record.dart';
import '../../../../core/data/models/site_package_record.dart';
import '../../../../core/network/file_downloader.dart';
import '../../../../core/storage/directory_manager.dart';

/// Pre-download summary shown in the "Karnak: 47 files, 132 MB — download?"
/// confirm dialog, per FLUTTER_MOBILE_PLAN.md Phase 1.
class DownloadEstimate {
  const DownloadEstimate({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

/// Orchestrates Phase 1's full-download flow: fetch the package manifest,
/// download `site_package.json` + every referenced `floor_{id}.json` +
/// every background image, persist everything locally, mark the site
/// ready. A site is never partially usable — [downloadSite] only updates
/// the `sites`/`floors` boxes once every file for the version has landed.
class SiteDownloadService {
  SiteDownloadService({
    required SiteRemoteDataSource remote,
    required SiteLocalDataSource local,
    required FileDownloader downloader,
    required DirectoryManager directoryManager,
    required Dio rawDio,
  }) : _remote = remote,
       _local = local,
       _downloader = downloader,
       _directoryManager = directoryManager,
       _rawDio = rawDio;

  final SiteRemoteDataSource _remote;
  final SiteLocalDataSource _local;
  final FileDownloader _downloader;
  final DirectoryManager _directoryManager;

  /// Package/floor/image URLs from `GET /sites/{id}/package` are
  /// signed/direct absolute URLs, not `/api/...` paths — a plain Dio
  /// instance (no auth header, no api base URL) fetches them directly.
  final Dio _rawDio;

  Future<DownloadEstimate> estimate(String siteId) async {
    final bundle = await _fetchBundle(siteId);
    var totalBytes = bundle.siteJsonBytes.length;
    for (final floorBytes in bundle.floorJsonBytes.values) {
      totalBytes += floorBytes.length;
    }

    var fileCount = 1 + bundle.floorJson.length;
    for (final url in bundle.imageUrls) {
      fileCount++;
      totalBytes += await _probeSize(url);
    }

    return DownloadEstimate(fileCount: fileCount, totalBytes: totalBytes);
  }

  Future<void> downloadSite(
    String siteId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final bundle = await _fetchBundle(siteId);
    final packageDir = await _directoryManager.packageDir(siteId);
    final imagesDir = Directory(p.join(packageDir.path, 'images'))
      ..createSync(recursive: true);

    final totalSteps = 1 + bundle.floorJson.length + bundle.imageUrls.length;
    var completedSteps = 0;
    void tick() => onProgress?.call(++completedSteps, totalSteps);

    await File(
      p.join(packageDir.path, 'site_package.json'),
    ).writeAsBytes(bundle.siteJsonBytes);
    tick();

    for (final entry in bundle.floorJsonBytes.entries) {
      await File(
        p.join(packageDir.path, 'floor_${entry.key}.json'),
      ).writeAsBytes(entry.value);
      tick();
    }

    for (final url in bundle.imageUrls) {
      final fileName = _fileNameForUrl(url);
      await _downloader.download(url, p.join(imagesDir.path, fileName));
      tick();
    }

    final now = DateTime.now();
    final existing = _local.getSite(siteId);
    await _local.putSite(
      (existing ?? SitePackageRecord(siteId: siteId, name: bundle.siteName))
          .copyWith(
            name: bundle.siteName,
            raw: bundle.siteJson,
            localVersion: bundle.manifest.version,
            latestVersion: bundle.manifest.version,
            latestPublishedAt: bundle.manifest.publishedAt,
            downloadedAt: now,
          ),
    );

    for (final entry in bundle.floorJson.entries) {
      await _local.putFloor(
        FloorPackageRecord(
          floorId: entry.key,
          siteId: siteId,
          raw: entry.value,
          downloadedAt: now,
        ),
      );
    }
  }

  Future<_FetchedBundle> _fetchBundle(String siteId) async {
    final manifest = await _remote.fetchPackageManifest(siteId);

    final sitePackageUrl = manifest.files['site_package'];
    if (sitePackageUrl == null) {
      throw StateError('Package manifest has no site_package entry.');
    }
    final siteJsonBytes = await _getBytes(sitePackageUrl);
    final siteJson =
        jsonDecode(utf8.decode(siteJsonBytes)) as Map<String, dynamic>;

    final floorIds = <String>{};
    for (final building in (siteJson['buildings'] as List).cast<Map>()) {
      for (final floorRef in (building['floors'] as List).cast<Map>()) {
        floorIds.add(floorRef['id'].toString());
      }
    }

    final floorJsonBytes = <String, List<int>>{};
    final floorJson = <String, Map<String, dynamic>>{};
    for (final floorId in floorIds) {
      final url = manifest.files['floor_$floorId'];
      if (url == null) continue;
      final bytes = await _getBytes(url);
      floorJsonBytes[floorId] = bytes;
      floorJson[floorId] = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }

    final imageUrls = _collectImageUrls(siteJson, floorJson);

    return _FetchedBundle(
      manifest: manifest,
      siteName: (siteJson['site'] as Map)['name'] as String,
      siteJson: siteJson,
      siteJsonBytes: siteJsonBytes,
      floorJson: floorJson,
      floorJsonBytes: floorJsonBytes,
      imageUrls: imageUrls,
    );
  }

  Set<String> _collectImageUrls(
    Map<String, dynamic> siteJson,
    Map<String, Map<String, dynamic>> floorJson,
  ) {
    final urls = <String>{};

    void addIfPresent(Object? value) {
      if (value is String && value.isNotEmpty) urls.add(value);
    }

    addIfPresent((siteJson['overview_canvas'] as Map?)?['background_image_url']);
    for (final building in (siteJson['buildings'] as List).cast<Map>()) {
      addIfPresent(
        (building['building_canvas'] as Map?)?['background_image_url'],
      );
    }
    for (final floor in floorJson.values) {
      addIfPresent((floor['canvas'] as Map?)?['background_image_url']);
    }

    return urls;
  }

  Future<List<int>> _getBytes(String url) async {
    final response = await _rawDio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  Future<int> _probeSize(String url) async {
    try {
      final response = await _rawDio.head(url);
      final contentLength = response.headers.value(
        Headers.contentLengthHeader,
      );
      return contentLength != null ? int.tryParse(contentLength) ?? 0 : 0;
    } on DioException {
      return 0;
    }
  }

  String _fileNameForUrl(String url) {
    final path = Uri.parse(url).path;
    return p.basename(path);
  }
}

class _FetchedBundle {
  const _FetchedBundle({
    required this.manifest,
    required this.siteName,
    required this.siteJson,
    required this.siteJsonBytes,
    required this.floorJson,
    required this.floorJsonBytes,
    required this.imageUrls,
  });

  final PackageManifest manifest;
  final String siteName;
  final Map<String, dynamic> siteJson;
  final List<int> siteJsonBytes;
  final Map<String, Map<String, dynamic>> floorJson;
  final Map<String, List<int>> floorJsonBytes;
  final Set<String> imageUrls;
}
