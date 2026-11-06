import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/errors/failure.dart';
import '../../data/datasources/follow_up_local_data_source.dart';
import '../../data/datasources/follow_up_remote_data_source.dart';
import '../../data/models/follow_up_upload_record.dart';

/// Sends queued follow-up photographs, grids and target widths, and collects
/// what became of them.
///
/// Separate from SyncQueueRunner, which is built around walls: here each
/// photograph is one upload, identified by its token, so a retry can never
/// create a second one on the server.
class FollowUpUploadRunner {
  FollowUpUploadRunner({
    required FollowUpLocalDataSource local,
    required FollowUpRemoteDataSource remote,
    required Future<File?> Function(String storedPath) resolveFile,
    Future<String> Function(FollowUpUploadRecord record)? stitchedPreviewPath,
  }) : _local = local,
       _remote = remote,
       _resolveFile = resolveFile,
       _stitchedPreviewPath = stitchedPreviewPath;

  final FollowUpLocalDataSource _local;
  final FollowUpRemoteDataSource _remote;
  final Future<File?> Function(String storedPath) _resolveFile;

  /// Where a grid's stitched picture goes. Without it, its montage stays.
  final Future<String> Function(FollowUpUploadRecord record)? _stitchedPreviewPath;

  /// The server's request limit on a results call.
  static const int _resultsBatch = 200;

  /// Statuses the server will not change again, so the phone can stop asking
  /// and drop its copy of the file. Not `pushed` on a photograph: that one waits
  /// for the studio's decision.
  static const _finalServerStatuses = {
    'kept',
    'reverted',
    'superseded',
    'rejected',
    'refused',
    'studio_approved',
    'studio_rejected',
    'stitch_failed',
    'declined',
  };

  /// Where a grid has no stitched picture to show. Any other status means it was
  /// stitched at least partly, whether or not that picture is in use.
  static const _noPictureStatuses = {
    null,
    'receiving',
    'stitching',
    'stitch_failed',
    'declined',
    'superseded',
  };

  /// A width's own ending. `held` isn't one: it can still be chosen at the studio.
  static const _finalWidthStatuses = {'pushed', 'kept'};

  /// Refusals: the same request would be refused again, so it isn't retried.
  static const _refusedStatusCodes = {403, 404, 409, 422};

  bool _draining = false;

  final ValueNotifier<int> _changes = ValueNotifier(0);

  /// Fires on any change, for every screen that's open.
  Listenable get changes => _changes;

  void _changed() => _changes.value++;

  bool _isFinal(FollowUpUploadRecord record) => record.kind == FollowUpUploadRecord.kindWidth
      ? _finalWidthStatuses.contains(record.serverStatus)
      : _finalServerStatuses.contains(record.serverStatus);

  /// Sends everything queued, then asks about everything sent. A second call
  /// while one is running returns at once: the running one will reach any new
  /// item, and two at once could send the same photograph together.
  Future<void> drainAll() async {
    if (_draining) return;
    _draining = true;
    try {
      final pending = _local.all().where(
        (r) =>
            r.status == FollowUpUploadRecord.statusQueued ||
            r.status == FollowUpUploadRecord.statusUploading,
      );
      for (final record in pending.toList()) {
        final keepGoing = await _send(record);
        if (!keepGoing) return;
      }
      await refreshResults();
    } finally {
      _draining = false;
      _changed();
    }
  }

  /// False when no further upload can succeed right now: there's no connection,
  /// or the session ended. Those stay queued for the next drain.
  Future<bool> _send(FollowUpUploadRecord record) async {
    final isWidth = record.kind == FollowUpUploadRecord.kindWidth;
    final hasNoFile = isWidth || record.isGrid;
    final file = hasNoFile ? null : await _resolveFile(record.filePath);
    if ((!hasNoFile && file == null) || (record.isGrid && !await _unsentTilesAreHere(record))) {
      record.status = FollowUpUploadRecord.statusFailed;
      record.lastError = 'The photograph is no longer on this phone. Take it again.';
      await _local.put(record);
      return true;
    }

    record.status = FollowUpUploadRecord.statusUploading;
    await _local.put(record);
    _changed();

    try {
      if (isWidth) {
        await _remote.uploadWidth(record);
      } else if (record.isGrid) {
        await _sendGrid(record);
      } else {
        await _remote.upload(
          record,
          openBytes: file!.openRead,
          length: await file.length(),
        );
      }
      record.status = FollowUpUploadRecord.statusSent;
      record.lastError = null;
      await _local.put(record);
      return true;
    } on AppException catch (e) {
      record.attempts += 1;
      record.lastError = e.failure.message;
      final refused = _isRefused(e.failure);
      record.status = refused
          ? FollowUpUploadRecord.statusFailed
          : FollowUpUploadRecord.statusQueued;
      await _local.put(record);
      return refused || e.failure is ServerFailure;
    } catch (e) {
      record.attempts += 1;
      record.lastError = e.toString();
      record.status = FollowUpUploadRecord.statusQueued;
      await _local.put(record);
      return true;
    }
  }

  Future<bool> _unsentTilesAreHere(FollowUpUploadRecord record) async {
    for (final tile in record.tiles) {
      if (!tile.sent && await _resolveFile(tile.path) == null) return false;
    }
    return true;
  }

  /// Announces the grid, then sends what the dashboard doesn't have yet. Each
  /// photograph is remembered as it lands, so a dropped connection resumes there.
  /// Its file goes at the same moment: the dashboard has checked it, and nothing
  /// ever sends one twice. A retake is a new grid.
  Future<void> _sendGrid(FollowUpUploadRecord record) async {
    await _remote.registerGrid(record);

    for (final tile in record.tiles) {
      if (tile.sent) continue;
      final file = await _resolveFile(tile.path);
      if (file == null) throw StateError('A photograph of this grid disappeared while sending.');

      await _remote.uploadGridTile(
        record.token,
        tile,
        openBytes: file.openRead,
        length: await file.length(),
      );

      record.tiles = [
        for (final each in record.tiles)
          each.row == tile.row && each.col == tile.col
              ? GridTile(row: each.row, col: each.col, path: each.path, sha256: each.sha256, sent: true)
              : each,
      ];
      await _local.put(record);
      await file.delete();
      _changed();
    }
  }

  /// Answers a grid with cells missing. Throws [AppException] with no connection,
  /// so the page can say so: this one can't wait in a queue, because the person
  /// is standing at the wall deciding whether to photograph it again.
  Future<void> decideGrid(FollowUpUploadRecord record, {required bool use}) async {
    await _apply(record, await _remote.decideGrid(record.token, use: use));
    _changed();
  }

  bool _isRefused(Failure failure) =>
      failure is ValidationFailure ||
      (failure is ServerFailure && _refusedStatusCodes.contains(failure.statusCode));

  Future<void> refreshResults() async {
    final waiting = _local
        .all()
        .where(
          (r) =>
              r.status == FollowUpUploadRecord.statusSent && !_isFinal(r),
        )
        .toList();

    try {
      for (var start = 0; start < waiting.length; start += _resultsBatch) {
        final batch = waiting.sublist(start, math.min(start + _resultsBatch, waiting.length));
        final results = await _remote.results(batch.map((r) => r.token).toList());
        final byToken = {for (final record in batch) record.token: record};
        for (final result in results) {
          final record = byToken[result['token']];
          if (record != null) await _apply(record, result);
        }
      }
    } on AppException {
      // Asked again on the next drain: nothing is lost by not knowing yet.
    }
    await _fetchStitchedPictures();
    _changed();
  }

  /// Apart from asking about results, because a picture that couldn't be fetched
  /// is still wanted once the record has reached a status nobody asks about again.
  Future<void> _fetchStitchedPictures() async {
    final stitchedPreviewPath = _stitchedPreviewPath;
    if (stitchedPreviewPath == null) return;

    final wanted = _local.all().where(
      (r) =>
          r.isGrid &&
          r.status == FollowUpUploadRecord.statusSent &&
          !r.hasStitchedPreview &&
          !_noPictureStatuses.contains(r.serverStatus),
    );

    for (final record in wanted.toList()) {
      final target = await stitchedPreviewPath(record);
      final partial = '$target.part';
      try {
        await _remote.downloadGridPreview(record.token, partial);
        await File(partial).rename(target);
      } on AppException {
        continue; // Only for showing: the montage stays until a later drain gets it.
      } on FileSystemException {
        continue;
      }

      final montage = record.previewPath;
      record.previewPath = target;
      await _local.put(record);
      if (montage != null) {
        final file = File(montage);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _apply(FollowUpUploadRecord record, Map<String, dynamic> result) async {
    record.serverStatus = result['status'] as String?;
    record.grade = result['grade'] as String?;
    record.baselineGrade = result['baseline_grade'] as String?;
    record.reasons = [for (final reason in result['reasons'] as List? ?? const []) reason as String];
    record.rejectReason = result['reject_reason'] as String?;
    if (result.containsKey('failed_cells')) {
      record.failedCellsJson = jsonEncode(result['failed_cells']);
    }
    await _local.put(record);

    if (!_isFinal(record)) return;

    final paths = [
      if (record.filePath.isNotEmpty) record.filePath,
      // Any left: one overtaken by a newer photograph before all of it was sent.
      for (final tile in record.tiles)
        if (!tile.sent) tile.path,
    ];
    for (final path in paths) {
      final file = await _resolveFile(path);
      if (file != null && await file.exists()) await file.delete();
    }
  }
}
