import 'package:hive/hive.dart';

import 'hive_type_ids.dart';

part 'site_package_record.g.dart';

/// Box [HiveBoxes.sites], keyed by [siteId]. Serves two purposes that
/// deliberately share one record rather than two Hive types:
///  - catalog metadata from `GET /sites` (name, location, latest known
///    server version) — present for every known site, even one never
///    downloaded, so the sites list works offline after the first sync;
///  - the downloaded bundle itself ([raw], mirroring `site_package.json`
///    per FLUTTER_MOBILE_PLAN.md §3) — null until [startDownload] succeeds.
@HiveType(typeId: HiveTypeIds.sitePackageRecord)
class SitePackageRecord extends HiveObject {
  SitePackageRecord({
    required this.siteId,
    required this.name,
    this.location,
    this.latestVersion,
    this.latestPublishedAt,
    this.raw,
    this.localVersion,
    this.downloadedAt,
  });

  @HiveField(0)
  final String siteId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? location;

  /// The newest version the server has published, per `GET /sites`'s
  /// `latest_package.version` — compared against [localVersion] to drive
  /// `SiteEntity.updateAvailable`.
  @HiveField(3)
  final int? latestVersion;

  @HiveField(4)
  final DateTime? latestPublishedAt;

  /// The decoded `site_package.json` body (site, overview_canvas,
  /// buildings[]). Null until a download has completed.
  @HiveField(5)
  final Map<dynamic, dynamic>? raw;

  /// The version of [raw] currently on disk.
  @HiveField(6)
  final int? localVersion;

  @HiveField(7)
  final DateTime? downloadedAt;

  bool get isDownloaded => raw != null;

  SitePackageRecord copyWith({
    String? name,
    String? location,
    int? latestVersion,
    DateTime? latestPublishedAt,
    Map<dynamic, dynamic>? raw,
    int? localVersion,
    DateTime? downloadedAt,
  }) {
    return SitePackageRecord(
      siteId: siteId,
      name: name ?? this.name,
      location: location ?? this.location,
      latestVersion: latestVersion ?? this.latestVersion,
      latestPublishedAt: latestPublishedAt ?? this.latestPublishedAt,
      raw: raw ?? this.raw,
      localVersion: localVersion ?? this.localVersion,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }
}
