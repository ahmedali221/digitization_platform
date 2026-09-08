import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../../core/domain/entities/site.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/domain/repositories/site_repository.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/public_downloads_channel.dart';
import '../../../grid_capture/domain/repositories/grid_capture_repository.dart';
import '../../../unassigned_walls/domain/repositories/unassigned_wall_repository.dart';

/// One captured photo destined for the backup zip: [archivePath] mirrors the
/// site's building/floor/wall structure; [sourcePath] is where the shot
/// actually lives on disk right now.
typedef _BackupShot = ({String archivePath, String sourcePath});

/// Bundles every captured photo for a site into a single zip, laid out to
/// mirror the site's building/floor/wall hierarchy — a portable, human-
/// browsable copy the operator can hand off or store outside the app
/// sandbox. Read-only over the same repositories the capture UI uses; never
/// mutates capture state.
///
/// Walls still awaiting floor/room assignment (`unassigned_walls`) aren't
/// part of that hierarchy yet, so their photos land under a top-level
/// `Unassigned/{wall title}/` folder instead.
class SiteBackupService {
  SiteBackupService({
    required SiteRepository siteRepository,
    required GridCaptureRepository gridCaptureRepository,
    required UnassignedWallRepository unassignedWallRepository,
    required DirectoryManager directoryManager,
  }) : _siteRepository = siteRepository,
       _gridCaptureRepository = gridCaptureRepository,
       _unassignedWallRepository = unassignedWallRepository,
       _directoryManager = directoryManager;

  static const _unassignedFolderName = 'Unassigned';

  final SiteRepository _siteRepository;
  final GridCaptureRepository _gridCaptureRepository;
  final UnassignedWallRepository _unassignedWallRepository;
  final DirectoryManager _directoryManager;

  /// Builds the zip and returns its path. [onProgress] reports shots added
  /// so far against the total — called only once the full file list (and
  /// therefore the total) is already known.
  Future<String> backupSite(
    String siteId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final site = _siteRepository.findSite(siteId);
    if (site == null) {
      throw StateError('Site not found: $siteId');
    }

    final shots = await _collectShots(site);
    if (shots.isEmpty) {
      throw StateError('No captured photos to back up yet.');
    }

    final exportDir = await _directoryManager.exportsDir(siteId);
    await _deletePreviousZips(exportDir);
    final zipFileName = _zipFileName(site.name);
    final zipPath = p.join(exportDir.path, zipFileName);
    final encoder = ZipFileEncoder()..create(zipPath);

    try {
      var done = 0;
      for (final shot in shots) {
        final file = await _directoryManager.resolveExistingFile(
          shot.sourcePath,
        );
        if (file == null) continue; // moved/deleted since capture — skip it
        await encoder.addFile(file, shot.archivePath);
        done++;
        onProgress?.call(done, shots.length);
      }
    } finally {
      await encoder.close();
    }

    // Best-effort: also lands the zip in the device's public Downloads
    // folder on Android, so it's browsable without going through the share
    // sheet. iOS keeps the share sheet as its only path — see
    // PublicDownloadsChannel's doc comment for why.
    await PublicDownloadsChannel.exportToDownloads(File(zipPath), zipFileName);

    return zipPath;
  }

  /// Keeps only the latest backup per site on disk — otherwise every run
  /// adds another timestamped zip to app-private storage forever. Doesn't
  /// touch any copy already exported to the public Downloads folder; once
  /// there, it's the user's own download to manage, not this app's to prune.
  Future<void> _deletePreviousZips(Directory exportDir) async {
    if (!await exportDir.exists()) return;
    await for (final entity in exportDir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        await entity.delete();
      }
    }
  }

  Future<List<_BackupShot>> _collectShots(SiteEntity site) async {
    final shots = <_BackupShot>[];

    for (final building in site.buildings) {
      for (final floor in building.floors) {
        for (final wall in floor.walls) {
          final captured = _gridCaptureRepository.getWall(floor.id, wall.id);
          _addWallShots(
            shots,
            grid: captured?.grid,
            folder: p.posix.joinAll([
              _sanitize(site.name),
              _sanitize(building.name),
              _sanitize(floor.name),
              _sanitize(wall.name),
            ]),
          );
        }
      }
    }

    final unassignedWalls = await _unassignedWallRepository
        .watchUnassignedWalls()
        .first;
    for (final wall in unassignedWalls.where((w) => w.siteId == site.id)) {
      final captured = _gridCaptureRepository.getWall(
        wall.floorId,
        wall.localId,
      );
      _addWallShots(
        shots,
        grid: captured?.grid,
        folder: p.posix.joinAll([
          _sanitize(site.name),
          _unassignedFolderName,
          _sanitize(wall.title.isEmpty ? wall.localId : wall.title),
        ]),
      );
    }

    return shots;
  }

  void _addWallShots(
    List<_BackupShot> shots, {
    required GridState? grid,
    required String folder,
  }) {
    if (grid == null) return;
    for (final cell in grid.cells) {
      for (final path in cell.shotPaths) {
        shots.add((
          archivePath: p.posix.join(folder, p.basename(path)),
          sourcePath: path,
        ));
      }
    }
  }

  String _zipFileName(String siteName) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return '${_sanitize(siteName)}_backup_$stamp.zip';
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  /// Strips filesystem-hostile characters so site/building/floor/wall names
  /// are always safe path segments — these come from user/dashboard input
  /// and aren't otherwise validated for that.
  String _sanitize(String name) {
    final cleaned = name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? 'Unnamed' : cleaned;
  }
}
