import '../../data/models/follow_up_upload_record.dart';
import '../entities/follow_up_package.dart';
import '../entities/new_target_details.dart';
import '../entities/target_width.dart';

/// Targets a site had no profile for, photographed during follow-up to become
/// profiles in the studio once the dashboard approves them. They travel with the
/// rest of the follow-up uploads, so they wait for a connection the same way.
abstract class NewTargetRepository {
  /// Queues a new target and tries to send it. If it throws, [photoPath] is as
  /// it was, so it can be tried again.
  Future<void> queueNewTarget({
    required FollowUpPackage package,
    required NewTargetDetails details,
    required String photoPath,
    required TargetWidth width,
  });

  /// The new targets added at this site, newest first.
  List<FollowUpUploadRecord> newTargets(String siteId);

  /// Why [code] can't be used for a new target at this site, or null when it
  /// can: a target of the package goes by it, or another new target holds it.
  String? codeConflict(FollowUpPackage package, String code);
}
