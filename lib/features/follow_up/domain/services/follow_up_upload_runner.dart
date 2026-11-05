import 'dart:io';
import 'dart:math' as math;

import '../../../../core/errors/failure.dart';
import '../../data/datasources/follow_up_local_data_source.dart';
import '../../data/datasources/follow_up_remote_data_source.dart';
import '../../data/models/follow_up_upload_record.dart';

/// Sends queued follow-up photographs and collects what became of them.
///
/// Separate from SyncQueueRunner, which is built around walls: here each
/// photograph is one upload, identified by its token, so a retry can never
/// create a second one on the server.
class FollowUpUploadRunner {
  FollowUpUploadRunner({
    required FollowUpLocalDataSource local,
    required FollowUpRemoteDataSource remote,
    required Future<File?> Function(String storedPath) resolveFile,
  }) : _local = local,
       _remote = remote,
       _resolveFile = resolveFile;

  final FollowUpLocalDataSource _local;
  final FollowUpRemoteDataSource _remote;
  final Future<File?> Function(String storedPath) _resolveFile;

  /// The server's request limit on a results call.
  static const int _resultsBatch = 200;

  /// Statuses the server will not change again, so the phone can stop asking
  /// and drop its copy of the file.
  static const _finalServerStatuses = {
    'kept',
    'reverted',
    'superseded',
    'pushed',
    'rejected',
  };

  /// Refusals: the same request would be refused again, so it isn't retried.
  static const _refusedStatusCodes = {403, 404, 409, 422};

  bool _draining = false;

  /// Reports a change, for a screen that's open.
  void Function()? onChanged;

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
      onChanged?.call();
    }
  }

  /// False when no further upload can succeed right now: there's no connection,
  /// or the session ended. Those stay queued for the next drain.
  Future<bool> _send(FollowUpUploadRecord record) async {
    final file = await _resolveFile(record.filePath);
    if (file == null) {
      record.status = FollowUpUploadRecord.statusFailed;
      record.lastError = 'The photograph is no longer on this phone. Take it again.';
      await _local.put(record);
      return true;
    }

    record.status = FollowUpUploadRecord.statusUploading;
    await _local.put(record);
    onChanged?.call();

    try {
      await _remote.upload(
        record,
        openBytes: file.openRead,
        length: await file.length(),
      );
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

  bool _isRefused(Failure failure) =>
      failure is ValidationFailure ||
      (failure is ServerFailure && _refusedStatusCodes.contains(failure.statusCode));

  Future<void> refreshResults() async {
    final waiting = _local
        .all()
        .where(
          (r) =>
              r.status == FollowUpUploadRecord.statusSent &&
              !_finalServerStatuses.contains(r.serverStatus),
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
  }

  Future<void> _apply(FollowUpUploadRecord record, Map<String, dynamic> result) async {
    record.serverStatus = result['status'] as String?;
    record.grade = result['grade'] as String?;
    record.baselineGrade = result['baseline_grade'] as String?;
    record.reasons = [for (final reason in result['reasons'] as List? ?? const []) reason as String];
    record.rejectReason = result['reject_reason'] as String?;
    await _local.put(record);

    if (_finalServerStatuses.contains(record.serverStatus)) {
      final file = await _resolveFile(record.filePath);
      if (file != null && await file.exists()) await file.delete();
    }
  }
}
