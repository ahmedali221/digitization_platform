/// How one kind of capture reaches the server. `SyncQueueRunner` owns the
/// queue item's lifecycle (status, retries, registering an item created on
/// this phone); an uploader only knows how to send its own kind of photos.
abstract class CaptureUploader {
  /// Whether this phone still holds a capture for [localWallId].
  bool hasCapture(String localWallId);

  /// Sends the capture this phone keeps under [localWallId] to the wall the
  /// server knows as [serverWallId], and returns once the server has
  /// confirmed it holds every photo — the point after which local backup
  /// copies may be deleted. [onProgress] runs from 0 to 1.
  ///
  /// Throws `AppException` on failure; the runner decides whether to retry.
  Future<void> upload({
    required String localWallId,
    required String serverWallId,
    required String siteId,
    required void Function(double fraction) onProgress,
  });

  /// Removes whatever redundant copies exist only to survive a failed
  /// upload. Called once [upload] has returned.
  Future<void> deleteBackups({
    required String localWallId,
    required String siteId,
  });
}
