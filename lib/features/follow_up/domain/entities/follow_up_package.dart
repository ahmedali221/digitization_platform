/// What a phone takes to a site to fix what the dashboard's index check found.
/// Parsed from the manifest the dashboard's FollowUpPackageBuilder writes, and
/// kept on disk as that same JSON, so everything here works with no signal.
class FollowUpPackage {
  const FollowUpPackage({
    required this.id,
    required this.siteId,
    required this.siteName,
    required this.createdAt,
    required this.totalBytes,
    required this.annotations,
    required this.targets,
    required this.files,
  });

  factory FollowUpPackage.fromJson(Map<String, dynamic> json) {
    final site = json['site'] as Map<String, dynamic>;
    return FollowUpPackage(
      id: json['id'] as int,
      siteId: site['id'].toString(),
      siteName: site['name'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      totalBytes: json['total_bytes'] as int? ?? 0,
      annotations: [
        for (final item in json['annotations'] as List? ?? const [])
          FollowUpAnnotation.fromJson(item as Map<String, dynamic>),
      ],
      targets: [
        for (final item in json['targets'] as List? ?? const [])
          FollowUpTarget.fromJson(item as Map<String, dynamic>),
      ],
      files: {
        for (final entry
            in (json['files'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: PackageFile.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }

  final int id;
  final String siteId;
  final String siteName;
  final DateTime? createdAt;
  final int totalBytes;
  final List<FollowUpAnnotation> annotations;
  final List<FollowUpTarget> targets;
  final Map<String, PackageFile> files;
}

class PackageFile {
  const PackageFile({required this.url, required this.size, required this.sha256});

  factory PackageFile.fromJson(Map<String, dynamic> json) => PackageFile(
    url: json['url'] as String,
    size: json['size'] as int,
    sha256: json['sha256'] as String,
  );

  final String url;
  final int size;
  final String sha256;
}

class FollowUpWall {
  const FollowUpWall({required this.id, required this.name, this.location = ''});

  factory FollowUpWall.fromJson(Map<String, dynamic> json) => FollowUpWall(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    location: json['location'] as String? ?? '',
  );

  final int id;
  final String name;
  final String location;
}

/// A point on a wall picture, as fractions of its width and height.
class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  factory NormalizedPoint.fromJson(Map<String, dynamic> json) => NormalizedPoint(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
  );

  final double x;
  final double y;

  Map<String, double> toJson() => {'x': x, 'y': y};
}

class WallPicture {
  const WallPicture({required this.key, required this.width, required this.height});

  factory WallPicture.fromJson(Map<String, dynamic> json) => WallPicture(
    key: json['key'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
  );

  final String key;
  final int width;
  final int height;
}

class FollowUpAnnotation {
  const FollowUpAnnotation({
    required this.id,
    required this.referenceCode,
    required this.wall,
    required this.grade,
    required this.reasons,
    required this.picture,
    required this.polygon,
    required this.closeupKey,
  });

  factory FollowUpAnnotation.fromJson(Map<String, dynamic> json) {
    final picture = json['picture'] as Map<String, dynamic>?;
    return FollowUpAnnotation(
      id: json['id'] as int,
      referenceCode: json['reference_code'] as String? ?? '',
      wall: FollowUpWall.fromJson(json['wall'] as Map<String, dynamic>),
      grade: json['grade'] as String?,
      reasons: [
        for (final reason in json['reasons'] as List? ?? const []) reason as String,
      ],
      picture: picture == null ? null : WallPicture.fromJson(picture),
      polygon: [
        for (final point in json['polygon'] as List? ?? const [])
          NormalizedPoint.fromJson(point as Map<String, dynamic>),
      ],
      closeupKey: json['closeup_key'] as String?,
    );
  }

  final int id;
  final String referenceCode;
  final FollowUpWall wall;
  final String? grade;
  final List<String> reasons;
  final WallPicture? picture;
  final List<NormalizedPoint> polygon;
  final String? closeupKey;
}

class FollowUpTarget {
  const FollowUpTarget({
    required this.arKey,
    required this.label,
    required this.description,
    required this.wall,
    required this.imageKey,
    required this.videoFrameKey,
    required this.hasVideo,
  });

  factory FollowUpTarget.fromJson(Map<String, dynamic> json) => FollowUpTarget(
    arKey: json['ar_key'] as String,
    label: json['label'] as String? ?? '',
    description: json['description'] as String?,
    wall: FollowUpWall.fromJson(json['wall'] as Map<String, dynamic>),
    imageKey: json['image_key'] as String,
    videoFrameKey: json['video_frame_key'] as String?,
    hasVideo: json['has_video'] as bool? ?? false,
  );

  final String arKey;
  final String label;
  final String? description;
  final FollowUpWall wall;
  final String imageKey;
  final String? videoFrameKey;
  final bool hasVideo;
}
