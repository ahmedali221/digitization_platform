import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Produces a stable, collision-safe local filename for a package image URL.
///
/// Canvas backgrounds are served through `/api/files?path=...`, so the URL
/// path alone is always `files`. Include a URL hash and recover the original
/// basename from the proxy's `path` query parameter to keep site, building,
/// and floor backgrounds distinct while retaining useful file extensions.
String packageImageFileName(String url) {
  final uri = Uri.parse(url);
  final sourcePath = uri.queryParameters['path']?.trim().isNotEmpty == true
      ? uri.queryParameters['path']!
      : uri.path;
  final basename = p.basename(sourcePath);
  final safeBasename = basename.isEmpty || basename == '.'
      ? 'canvas-image'
      : basename;
  final fingerprint = sha256
      .convert(utf8.encode(url))
      .toString()
      .substring(0, 16);
  return '${fingerprint}_$safeBasename';
}
