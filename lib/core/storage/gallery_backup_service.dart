import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// One recovered/backed-up photo, parsed back out of its filename.
typedef GalleryBackupEntry = ({AssetEntity asset, GalleryPhotoInfo info});

/// The wall/cell/shot mapping [GalleryBackupService] encodes into a
/// filename at backup time and decodes back out at recovery time.
typedef GalleryPhotoInfo = ({
  String siteId,
  String wallId,
  int row,
  int col,
  int shot,
});

/// Best-effort redundant copy of capture photos into the device's own
/// Photos library — storage outside the app's sandbox, so it survives a
/// true iOS reinstall (App Store/TestFlight sometimes reinstalls rather
/// than updates in place, wiping Documents/Hive entirely — see
/// AuthRepositoryImpl.hasValidSession). A recovery pass then scans this
/// back in after such a wipe (see the `grid_capture` feature's
/// CaptureRecoveryService).
///
/// Deliberately does *not* group photos into a dedicated album — Android's
/// MediaStore and iOS's PhotoKit differ enough in how album membership
/// works that doing so would add a large surface of platform-specific
/// failure for a cosmetic benefit. Photos land directly in the camera
/// roll/gallery (in a plain `Pictures/NileLens` folder on Android); the
/// `nilelens~~...` filename prefix is what makes them identifiable.
///
/// Every method here swallows its own errors — a missing/denied Photos
/// permission, or any platform failure, must never interrupt the actual
/// capture flow. This is a safety net, not a requirement.
class GalleryBackupService {
  static const _prefix = 'nilelens';
  static const _sep = '~~';
  static const _androidRelativePath = 'Pictures/NileLens';

  /// Saves a redundant copy of [file] into the device gallery, tagging it
  /// with the wall/cell/shot mapping so a later scan can reconstruct it.
  /// No-ops silently if the Photos permission isn't granted.
  Future<void> backupPhoto({
    required String siteId,
    required String wallId,
    required int row,
    required int col,
    required int shot,
    required File file,
  }) async {
    try {
      if (!await _hasPermission()) return;
      final bytes = await file.readAsBytes();
      await PhotoManager.editor.saveImage(
        bytes,
        filename: _buildFilename(
          siteId: siteId,
          wallId: wallId,
          row: row,
          col: col,
          shot: shot,
        ),
        relativePath: _androidRelativePath,
      );
    } catch (e) {
      debugPrint(
        'GalleryBackupService: backup failed for wall $wallId '
        'R${row}C$col S$shot: $e',
      );
    }
  }

  /// Deletes every backed-up photo for [wallId] once its session is
  /// confirmed server-side — mirrors DirectoryManager.deleteBackup's
  /// Invariant 1 (never delete a redundant copy before the server has the
  /// data). Without this, a fully-synced wall's gallery copies would sit
  /// here forever, and a later recovery scan could mistake them for
  /// still-unsynced orphans and re-upload already-confirmed captures.
  ///
  /// Note: iOS shows the user a native confirmation prompt before deleting
  /// Photos library items — that's a PhotoKit-level restriction, not
  /// something this app can suppress.
  Future<void> deleteWallBackup({
    required String siteId,
    required String wallId,
  }) async {
    try {
      if (!await _hasPermission()) return;
      final entries = await _scan();
      final ids = entries
          .where(
            (e) => e.info.siteId == siteId && e.info.wallId == wallId,
          )
          .map((e) => e.asset.id)
          .toList();
      if (ids.isEmpty) return;
      await PhotoManager.editor.deleteWithIds(ids);
    } catch (e) {
      debugPrint('GalleryBackupService: cleanup failed for wall $wallId: $e');
    }
  }

  /// Every backed-up photo currently in the gallery, tag-parsed and ready
  /// for [CaptureRecoveryService] to group by wall. Returns an empty list
  /// on any permission/platform failure rather than throwing, matching this
  /// class's best-effort contract.
  Future<List<GalleryBackupEntry>> scanBackups() async {
    try {
      if (!await _hasPermission()) return const [];
      return _scan();
    } catch (e) {
      debugPrint('GalleryBackupService: scan failed: $e');
      return const [];
    }
  }

  Future<bool> _hasPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state == PermissionState.authorized ||
        state == PermissionState.limited;
  }

  Future<List<GalleryBackupEntry>> _scan() async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) return const [];
    final root = paths.first;
    final count = await root.assetCountAsync;

    const pageSize = 200;
    final entries = <GalleryBackupEntry>[];
    for (var start = 0; start < count; start += pageSize) {
      final end = (start + pageSize).clamp(0, count);
      final assets = await root.getAssetListRange(start: start, end: end);
      for (final asset in assets) {
        final title = asset.title ?? await asset.titleAsync;
        final info = _parseFilename(title);
        if (info != null) entries.add((asset: asset, info: info));
      }
    }
    return entries;
  }

  String _buildFilename({
    required String siteId,
    required String wallId,
    required int row,
    required int col,
    required int shot,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_prefix$_sep$siteId$_sep$wallId$_sep$row$_sep$col$_sep'
        '$shot$_sep$timestamp.jpg';
  }

  GalleryPhotoInfo? _parseFilename(String filename) {
    final base = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    final parts = base.split(_sep);
    if (parts.length != 7 || parts[0] != _prefix) return null;

    final row = int.tryParse(parts[3]);
    final col = int.tryParse(parts[4]);
    final shot = int.tryParse(parts[5]);
    if (row == null || col == null || shot == null) return null;

    return (siteId: parts[1], wallId: parts[2], row: row, col: col, shot: shot);
  }
}
