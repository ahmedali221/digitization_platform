import 'package:flutter/foundation.dart';

import '../../data/models/follow_up_upload_record.dart';
import '../entities/follow_up_package.dart';
import '../entities/target_match_result.dart';
import '../entities/target_width.dart';

abstract class FollowUpRepository {
  /// The package already on this phone, usable with no signal.
  Future<FollowUpPackage?> localPackage(String siteId);

  /// The site's latest package on the server, or null when it has none.
  Future<FollowUpPackage?> remotePackage(String siteId);

  /// Fetches the files of [package], skipping those already here intact, so an
  /// interrupted download carries on. [onProgress] gets a fraction from 0 to 1.
  Future<void> download(
    FollowUpPackage package, {
    void Function(double fraction)? onProgress,
  });

  /// Where a package file is on this phone.
  Future<String> filePath(String siteId, String key);

  /// Everything sent or waiting to be sent from this site, newest first.
  List<FollowUpUploadRecord> uploads(String siteId);

  /// A folder for the shots of one photograph session.
  Future<String> newShotsFolder(String siteId);

  /// Queues a photograph of an annotation, in place of any earlier one of it
  /// that hasn't been sent yet, and tries to send it.
  Future<void> queueAnnotationCapture({
    required FollowUpPackage package,
    required FollowUpAnnotation annotation,
    required String photoPath,
  });

  /// Queues a grid of photographs of an annotation, for the dashboard to stitch,
  /// in place of any earlier photograph of it that hasn't been sent. [photos] is
  /// keyed by cell, row by row, and has one for every cell of [rows] by [cols].
  Future<void> queueAnnotationGrid({
    required FollowUpPackage package,
    required FollowUpAnnotation annotation,
    required int rows,
    required int cols,
    required Map<int, String> photos,
  });

  /// Answers a grid the dashboard could only partly stitch: use that picture, or
  /// not. Needs a connection: throws AppException without one.
  Future<void> decideGrid(FollowUpUploadRecord upload, {required bool use});

  /// Queues a photograph of a target, with its width and what the check against
  /// its video found. On the dashboard it waits for review before anything changes.
  Future<void> queueTargetCapture({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required String photoPath,
    required TargetMatchResult? match,
    required bool warningConfirmed,
    required TargetWidth width,
  });

  /// Queues a width for a target whose image stays as it is, in place of any
  /// earlier one that hasn't been sent yet.
  Future<void> queueTargetWidth({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required TargetWidth width,
  });

  /// Where a sent or waiting photograph can be seen on this phone, or null when
  /// it's gone: the small copy, or the original for one made before those existed.
  Future<String?> photoPath(FollowUpUploadRecord upload);

  /// Sends what's queued and collects results.
  Future<void> sync();

  /// Fires whenever an upload changes, for every screen that's open.
  Listenable get uploadsChanged;
}
