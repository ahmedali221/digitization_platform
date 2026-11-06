import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/target_match_result.dart';
import '../../domain/entities/target_width.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/services/follow_up_upload_runner.dart';
import '../../domain/services/shot_processing.dart';
import '../datasources/follow_up_local_data_source.dart';
import '../datasources/follow_up_remote_data_source.dart';
import '../models/follow_up_upload_record.dart';

class FollowUpRepositoryImpl implements FollowUpRepository {
  FollowUpRepositoryImpl({
    required FollowUpLocalDataSource local,
    required FollowUpRemoteDataSource remote,
    required DirectoryManager directoryManager,
    required FollowUpUploadRunner runner,
  }) : _local = local,
       _remote = remote,
       _directories = directoryManager,
       _runner = runner;

  final FollowUpLocalDataSource _local;
  final FollowUpRemoteDataSource _remote;
  final DirectoryManager _directories;
  final FollowUpUploadRunner _runner;

  static const _manifestName = 'manifest.json';
  static const _filesFolder = 'files';
  static const _capturesFolder = 'captures';
  static const _shotsFolder = 'shots';
  static const previewsFolder = 'previews';
  static const _uuid = Uuid();

  /// A new name rather than the montage's: the image cache goes by path, and
  /// would go on showing the montage.
  static String stitchedPreviewPath(Directory previews, String token) =>
      p.join(previews.path, '$token${FollowUpUploadRecord.stitchedPreviewSuffix}');

  @override
  Listenable get uploadsChanged => _runner.changes;

  @override
  Future<FollowUpPackage?> localPackage(String siteId) async {
    final manifest = File(p.join((await _directories.followUpDir(siteId)).path, _manifestName));
    if (!await manifest.exists()) return null;
    try {
      return FollowUpPackage.fromJson(
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<FollowUpPackage?> remotePackage(String siteId) => _remote.latestPackage(siteId);

  @override
  Future<void> download(
    FollowUpPackage package, {
    void Function(double fraction)? onProgress,
  }) async {
    final siteDir = await _directories.followUpDir(package.siteId);
    final filesDir = await _directories.followUpDir(package.siteId, _filesFolder);

    final needed = <String, PackageFile>{};
    var doneBytes = 0;
    for (final entry in package.files.entries) {
      final existing = File(p.join(filesDir.path, entry.key));
      if (await _isIntact(existing, entry.value)) {
        doneBytes += entry.value.size;
      } else {
        needed[entry.key] = entry.value;
      }
    }

    final neededBytes = needed.values.fold<int>(0, (sum, file) => sum + file.size);
    if (!await _directories.hasSufficientSpace(neededBytes)) {
      throw const AppException(
        UnknownFailure('Not enough free space on this phone for this package.'),
      );
    }

    final totalBytes = package.files.values.fold<int>(0, (sum, file) => sum + file.size);
    void report(int extra) {
      if (totalBytes > 0) onProgress?.call((doneBytes + extra) / totalBytes);
    }

    report(0);
    for (final entry in needed.entries) {
      final target = p.join(filesDir.path, entry.key);
      final partial = '$target.part';
      await _remote.downloadFile(entry.value.url, partial, onReceived: report);
      if (!await _isIntact(File(partial), entry.value)) {
        await File(partial).delete();
        throw const AppException(
          NetworkFailure('A file arrived damaged. Try the download again.'),
        );
      }
      await File(partial).rename(target);
      doneBytes += entry.value.size;
      report(0);
    }

    // Last, so a package only counts as here once all of it is.
    final manifest = File(p.join(siteDir.path, _manifestName));
    final temporary = File('${manifest.path}.part');
    await temporary.writeAsString(jsonEncode(_toJson(package)));
    await temporary.rename(manifest.path);

    await for (final item in filesDir.list()) {
      if (item is File && !package.files.containsKey(p.basename(item.path))) {
        await item.delete();
      }
    }

    await _dropPreviewsBefore(package);
  }

  /// This package's images already show whatever was approved from an earlier
  /// one, so those photographs aren't shown as "new" any more.
  Future<void> _dropPreviewsBefore(FollowUpPackage package) async {
    final earlier = uploads(package.siteId).where((r) => r.packageId != package.id && r.previewPath != null);
    for (final record in earlier) {
      final preview = File(record.previewPath!);
      if (await preview.exists()) await preview.delete();
    }
  }

  Future<bool> _isIntact(File file, PackageFile expected) async {
    if (!await file.exists() || await file.length() != expected.size) return false;
    return await _sha256(file) == expected.sha256;
  }

  Future<String> _sha256(File file) async =>
      (await crypto.sha256.bind(file.openRead()).first).toString();

  Map<String, dynamic> _toJson(FollowUpPackage package) => {
    'id': package.id,
    'site': {'id': int.tryParse(package.siteId) ?? package.siteId, 'name': package.siteName},
    'created_at': package.createdAt?.toIso8601String(),
    'total_bytes': package.totalBytes,
    'annotations': [
      for (final a in package.annotations)
        {
          'id': a.id,
          'reference_code': a.referenceCode,
          'wall': {'id': a.wall.id, 'name': a.wall.name, 'location': a.wall.location},
          'grade': a.grade,
          'reasons': a.reasons,
          'picture': a.picture == null
              ? null
              : {'key': a.picture!.key, 'width': a.picture!.width, 'height': a.picture!.height},
          'polygon': [for (final point in a.polygon) point.toJson()],
          'closeup_key': a.closeupKey,
        },
    ],
    'targets': [
      for (final t in package.targets)
        {
          'ar_key': t.arKey,
          'label': t.label,
          'description': t.description,
          'wall': t.wall == null ? null : {'id': t.wall!.id, 'name': t.wall!.name},
          'wall_label': t.wallLabel,
          'video_status': t.videoStatus,
          'image_key': t.imageKey,
          'video_frame_key': t.videoFrameKey,
          'has_video': t.hasVideo,
          'physical_width_m': t.physicalWidthM,
        },
    ],
    'files': {
      for (final entry in package.files.entries)
        entry.key: {'url': entry.value.url, 'size': entry.value.size, 'sha256': entry.value.sha256},
    },
  };

  @override
  Future<String> filePath(String siteId, String key) async =>
      p.join((await _directories.followUpDir(siteId, _filesFolder)).path, key);

  @override
  List<FollowUpUploadRecord> uploads(String siteId) =>
      _local.all().where((r) => r.siteId == siteId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<String?> photoPath(FollowUpUploadRecord upload) async {
    for (final stored in [upload.previewPath, upload.filePath]) {
      if (stored == null || stored.isEmpty) continue;
      final file = await _directories.resolveExistingFile(stored);
      if (file != null) return file.path;
    }
    return null;
  }

  @override
  Future<String> newShotsFolder(String siteId) async {
    final shots = await _directories.followUpDir(siteId, _shotsFolder);
    final folder = Directory(p.join(shots.path, _uuid.v4()));
    await folder.create(recursive: true);
    return folder.path;
  }

  @override
  Future<void> deleteShotsFolder(String folder) async {
    final directory = Directory(folder);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> queueAnnotationCapture({
    required FollowUpPackage package,
    required FollowUpAnnotation annotation,
    required String photoPath,
  }) => _queue(
    kind: FollowUpUploadRecord.kindAnnotation,
    siteId: package.siteId,
    packageId: package.id,
    itemKey: annotation.id.toString(),
    label: annotation.referenceCode,
    photoPath: photoPath,
  );

  @override
  Future<void> queueAnnotationGrid({
    required FollowUpPackage package,
    required FollowUpAnnotation annotation,
    required int rows,
    required int cols,
    required Map<int, String> photos,
  }) async {
    final itemKey = annotation.id.toString();
    final token = _uuid.v4();
    final captures = await _directories.followUpDir(package.siteId, _capturesFolder);
    final previews = await _directories.followUpDir(package.siteId, previewsFolder);
    final montagePath = p.join(previews.path, '$token.jpg');
    final written = <String>[montagePath];

    try {
      final tiles = <GridTile>[];
      for (final entry in photos.entries) {
        final row = entry.key ~/ cols;
        final col = entry.key % cols;
        final copyPath = p.join(captures.path, '${token}_r${row}c$col.jpg');
        written.add(copyPath);
        final file = await File(entry.value).copy(copyPath);
        tiles.add(GridTile(row: row, col: col, path: file.path, sha256: await _sha256(file)));
      }
      final previewPath = await _makeMontage(tiles, rows, cols, montagePath);
      final now = DateTime.now();

      // Not before the copies: running out of space must not cost the older one
      // too. And not after the new record, or a drain could send them both.
      await _discardUnsent(package.siteId, FollowUpUploadRecord.kindAnnotationGrid, itemKey);
      await _local.put(
        FollowUpUploadRecord(
          token: token,
          kind: FollowUpUploadRecord.kindAnnotationGrid,
          siteId: package.siteId,
          packageId: package.id,
          itemKey: itemKey,
          label: annotation.referenceCode,
          filePath: '',
          sha256: '',
          capturedAt: now,
          createdAt: now,
          rows: rows,
          cols: cols,
          previewPath: previewPath,
        )..tiles = tiles,
      );
    } catch (_) {
      await _deleteFiles(written);
      rethrow;
    }

    unawaited(_runner.drainAll());
  }

  /// Only for showing, like a photograph's preview.
  Future<String?> _makeMontage(List<GridTile> tiles, int rows, int cols, String target) async {
    try {
      final byRow = [
        for (var row = 0; row < rows; row++)
          [
            for (var col = 0; col < cols; col++)
              tiles.firstWhere((tile) => tile.row == row && tile.col == col).path,
          ],
      ];
      await compute(makeMontage, MontageRequest(rows: byRow, targetPath: target));
      return target;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> decideGrid(FollowUpUploadRecord upload, {required bool use}) =>
      _runner.decideGrid(upload, use: use);

  @override
  Future<void> queueTargetCapture({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required String photoPath,
    required TargetMatchResult? match,
    required bool warningConfirmed,
    required TargetWidth width,
  }) => _queue(
    kind: FollowUpUploadRecord.kindTarget,
    siteId: package.siteId,
    packageId: package.id,
    itemKey: target.arKey,
    label: target.label,
    photoPath: photoPath,
    videoMatchJson: match == null ? null : jsonEncode(match.toJson()),
    warningConfirmed: warningConfirmed,
    suggestedCornersJson: match?.frameCorners == null
        ? null
        : jsonEncode([for (final corner in match!.frameCorners!) corner.toJson()]),
    width: width,
  );

  @override
  Future<void> queueTargetWidth({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required TargetWidth width,
  }) async {
    await _discardUnsent(package.siteId, FollowUpUploadRecord.kindWidth, target.arKey);

    final now = DateTime.now();
    await _local.put(
      FollowUpUploadRecord(
        token: _uuid.v4(),
        kind: FollowUpUploadRecord.kindWidth,
        siteId: package.siteId,
        packageId: package.id,
        itemKey: target.arKey,
        label: target.label,
        filePath: '',
        sha256: '',
        capturedAt: now,
        physicalWidthM: _rounded(width.meters),
        widthSource: width.source,
        createdAt: now,
      ),
    );

    unawaited(_runner.drainAll());
  }

  /// Millimetres are more than either way of measuring can tell apart, and it's
  /// what every later step stores.
  double _rounded(double meters) => (meters * 1000).round() / 1000;

  Future<void> _queue({
    required String kind,
    required String siteId,
    required int packageId,
    required String itemKey,
    required String label,
    required String photoPath,
    String? videoMatchJson,
    bool warningConfirmed = false,
    String? suggestedCornersJson,
    TargetWidth? width,
  }) async {
    final token = _uuid.v4();
    final captures = await _directories.followUpDir(siteId, _capturesFolder);
    final copyPath = p.join(captures.path, '$token.jpg');
    final written = <String?>[copyPath];

    try {
      final file = await File(photoPath).copy(copyPath);
      final preview = await _makePreview(siteId, token, file.path);
      written.add(preview);
      final sha256 = await _sha256(file);
      final now = DateTime.now();

      // See queueAnnotationGrid for why it's exactly here.
      await _discardUnsent(siteId, kind, itemKey);
      await _local.put(
        FollowUpUploadRecord(
          token: token,
          kind: kind,
          siteId: siteId,
          packageId: packageId,
          itemKey: itemKey,
          label: label,
          filePath: file.path,
          sha256: sha256,
          capturedAt: now,
          videoMatchJson: videoMatchJson,
          warningConfirmed: warningConfirmed,
          suggestedCornersJson: suggestedCornersJson,
          createdAt: now,
          physicalWidthM: width == null ? null : _rounded(width.meters),
          widthSource: width?.source,
          previewPath: preview,
        ),
      );
    } catch (_) {
      await _deleteFiles(written);
      rethrow;
    }

    unawaited(_runner.drainAll());
  }

  /// Only for showing, so failing to make one mustn't lose the photograph.
  Future<String?> _makePreview(String siteId, String token, String source) async {
    try {
      final previews = await _directories.followUpDir(siteId, previewsFolder);
      final target = p.join(previews.path, '$token.jpg');
      await compute(makePreview, PreviewRequest(sourcePath: source, targetPath: target));
      return target;
    } catch (_) {
      return null;
    }
  }

  /// A newer one of the same thing: the older one need not be sent. Except target
  /// photographs: see FollowUpUploadRecord.replacedByNewerOne. A grid and a single
  /// photograph of an annotation replace each other: see FollowUpUploadRecord.family.
  /// If part of a grid already went, the dashboard drops it when the new one arrives.
  Future<void> _discardUnsent(String siteId, String kind, String itemKey) async {
    final family = kind == FollowUpUploadRecord.kindAnnotationGrid
        ? FollowUpUploadRecord.kindAnnotation
        : kind;
    final stale = _local.all().where(
      (r) =>
          r.replacedByNewerOne &&
          r.siteId == siteId &&
          r.family == family &&
          r.itemKey == itemKey &&
          (r.status == FollowUpUploadRecord.statusQueued ||
              r.status == FollowUpUploadRecord.statusFailed),
    );
    for (final record in stale.toList()) {
      await _deleteFiles([record.filePath, record.previewPath, for (final tile in record.tiles) tile.path]);
      await _local.delete(record.token);
    }
  }

  Future<void> _deleteFiles(Iterable<String?> paths) async {
    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> sync() => _runner.drainAll();
}
