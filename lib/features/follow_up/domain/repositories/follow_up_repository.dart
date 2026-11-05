import '../../data/models/follow_up_upload_record.dart';
import '../entities/follow_up_package.dart';
import '../entities/target_match_result.dart';

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

  /// Queues a photograph of a target, with what the check against its video
  /// found. On the dashboard it waits for review before anything changes.
  Future<void> queueTargetCapture({
    required FollowUpPackage package,
    required FollowUpTarget target,
    required String photoPath,
    required TargetMatchResult? match,
    required bool warningConfirmed,
  });

  /// Sends what's queued and collects results.
  Future<void> sync();

  /// Told whenever an upload changes, for a screen that's open.
  set onUploadsChanged(void Function()? listener);
}
