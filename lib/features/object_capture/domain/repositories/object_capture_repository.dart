import '../../../../core/domain/entities/object_type.dart';
import '../entities/object_capture.dart';

/// Contract for photographing an object: a statue, a stela, anything that
/// is a set of images rather than a grid. Narrow on purpose (CLAUDE.md's ISP
/// rule) — the wall itself is read through `SiteRepository`.
abstract class ObjectCaptureRepository {
  /// What this phone holds for [wallId]; empty before the first shot.
  ObjectCapture getCapture(String wallId);

  Stream<ObjectCapture> watchCapture(String wallId);

  /// Where the camera writes a shot before it is kept through
  /// [setSidePhoto] or [addFreePhotos].
  Future<String> incomingFolder(String wallId);

  /// Keeps the shot at [shotPath] as the photograph of [side], replacing the
  /// one already there. Organised capture has one image per side.
  Future<void> setSidePhoto({
    required String floorId,
    required String wallId,
    required ObjectSide side,
    required String shotPath,
  });

  /// Keeps the shots at [shotPaths] as free photographs. Each one's comment
  /// is written afterwards with [setComment], once the operator can see what
  /// they took.
  Future<void> addFreePhotos({
    required String floorId,
    required String wallId,
    required List<String> shotPaths,
  });

  /// Keeps, as free photographs, any shot the camera wrote for [wallId] that
  /// was never handed over — the app was closed with the camera open. A
  /// photograph taken is never dropped for want of a tap on "Done".
  Future<void> adoptStrayShots({
    required String floorId,
    required String wallId,
  });

  Future<void> setComment({
    required String wallId,
    required String photoPath,
    required String comment,
  });

  /// Removes the photograph from this phone, backup copy included.
  Future<void> deletePhoto({required String wallId, required String photoPath});

  /// Records where the capture stands on the wall's status and hands it to
  /// the upload queue. Safe to call again after more photographs are added.
  Future<void> save({required String floorId, required String wallId});
}
