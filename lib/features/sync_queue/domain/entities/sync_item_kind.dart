/// What a queued upload carries, which decides how it is sent
/// (see `CaptureUploader`). The names are stored in the queue, so renaming
/// one orphans every item already queued under it.
enum SyncItemKind {
  /// A wall's or painting's grid cells.
  gridSession,

  /// An object's side and free photographs.
  objectPhotos,

  /// The photographs of an object's 3D scan.
  objectScan;

  /// The queue's key for this kind of upload of [wallId]. A wall has one
  /// upload at a time, keyed by its own id, except that an object can have
  /// a 3D scan as well as its photographs: the scan queues beside them
  /// rather than in their place.
  String queueId(String wallId) => this == objectScan ? '$wallId#scan' : wallId;
}
