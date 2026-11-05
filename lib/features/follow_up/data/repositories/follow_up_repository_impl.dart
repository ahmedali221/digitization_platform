import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/storage/directory_manager.dart';
import '../../domain/entities/follow_up_package.dart';
import '../../domain/entities/target_match_result.dart';
import '../../domain/repositories/follow_up_repository.dart';
import '../../domain/services/follow_up_upload_runner.dart';
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
  static const _uuid = Uuid();

  @override
  set onUploadsChanged(void Function()? listener) => _runner.onChanged = listener;

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
          'wall': {'id': t.wall.id, 'name': t.wall.name},
          'image_key': t.imageKey,
          'video_frame_key': t.videoFrameKey,
          'has_video': t.hasVideo,
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
  Future<String> newShotsFolder(String siteId) async {
    final shots = await _directories.followUpDir(siteId, _shotsFolder);
    final folder = Directory(p.join(shots.path, _uuid.v4()));
    await folder.create(recursive: true);
    return folder.path;
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
  Future<void> queueTargetCapture({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required String photoPath,
    required TargetMatchResult? match,
    required bool warningConfirmed,
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
  );

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
  }) async {
    await _discardUnsent(siteId, kind, itemKey);

    final token = _uuid.v4();
    final captures = await _directories.followUpDir(siteId, _capturesFolder);
    final file = await File(photoPath).copy(p.join(captures.path, '$token.jpg'));
    final now = DateTime.now();

    await _local.put(
      FollowUpUploadRecord(
        token: token,
        kind: kind,
        siteId: siteId,
        packageId: packageId,
        itemKey: itemKey,
        label: label,
        filePath: file.path,
        sha256: await _sha256(file),
        capturedAt: now,
        videoMatchJson: videoMatchJson,
        warningConfirmed: warningConfirmed,
        suggestedCornersJson: suggestedCornersJson,
        createdAt: now,
      ),
    );

    unawaited(_runner.drainAll());
  }

  /// A newer photograph of the same thing: the older one need not be sent.
  Future<void> _discardUnsent(String siteId, String kind, String itemKey) async {
    final stale = _local.all().where(
      (r) =>
          r.siteId == siteId &&
          r.kind == kind &&
          r.itemKey == itemKey &&
          (r.status == FollowUpUploadRecord.statusQueued ||
              r.status == FollowUpUploadRecord.statusFailed),
    );
    for (final record in stale.toList()) {
      final file = File(record.filePath);
      if (await file.exists()) await file.delete();
      await _local.delete(record.token);
    }
  }

  @override
  Future<void> sync() => _runner.drainAll();
}
