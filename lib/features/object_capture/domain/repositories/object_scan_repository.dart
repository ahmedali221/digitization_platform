import '../entities/object_scan.dart';
import '../entities/scan_plan.dart';

/// The 3D scan of one object as this phone holds it: its photographs, the
/// handover to the server, and the server's answer.
abstract class ObjectScanRepository {
  /// Null until the first photograph of a scan is kept.
  ObjectScan? getScan(String wallId);

  Stream<ObjectScan?> watchScan(String wallId);

  /// Where the camera writes a shot before it is kept.
  Future<String> incomingFolder(String wallId);

  /// Keeps the photograph at [shotPath] as the one taken for [cell].
  Future<void> addShot({
    required String floorId,
    required String wallId,
    required String shotPath,
    required ScanCell cell,
  });

  /// The operator is done shooting: the scan is queued for upload.
  /// [fullCircle] is false when the object could not be walked all the way
  /// round, so its missing side is not held against the scan.
  Future<void> finish({
    required String floorId,
    required String wallId,
    required bool fullCircle,
  });

  /// Opens a finished scan for more photographs: those the server could not
  /// use are taken again, and the sides its rough model lacks are
  /// photographed once more beside what is held of them. With
  /// [fromTheStart], every photograph is given up and the scan begins
  /// again: the way out when the object was moved, so that nothing shot
  /// before can be joined to what comes next.
  Future<void> reopen(String wallId, {bool fromTheStart = false});

  /// Asks the server where the scan stands. Does nothing for a scan the
  /// server has not been told of yet.
  Future<void> refreshStatus(String wallId);
}
