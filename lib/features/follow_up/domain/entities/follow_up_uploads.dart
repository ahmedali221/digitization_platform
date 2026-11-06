import '../../data/models/follow_up_upload_record.dart';
import 'follow_up_package.dart';
import 'target_width.dart';

/// What was sent from the package on this phone, newest first, for one item: the
/// pages' "New". A later package already shows anything approved as the current
/// image, so an upload from an earlier one has nothing to compare with any more.
/// Asking for annotation photographs includes grids: see FollowUpUploadRecord.family.
List<FollowUpUploadRecord> newPhotosOf(
  FollowUpPackage package,
  Iterable<FollowUpUploadRecord> uploads, {
  required String kind,
  required String itemKey,
}) => [
  for (final upload in uploads)
    if (upload.family == kind && upload.itemKey == itemKey && upload.packageId == package.id) upload,
];

/// Whether the replacement of this target is settled: the phone is still showing
/// the old image, so another photograph needs a new package first.
bool targetWasReplaced(Iterable<FollowUpUploadRecord> photos) =>
    photos.any((photo) => photo.serverStatus == 'studio_approved');

/// Target photographs from this package that didn't go through, to tell someone
/// who might otherwise think they're still waiting.
int turnedDownPhotos(FollowUpPackage package, Iterable<FollowUpUploadRecord> uploads) => uploads
    .where(
      (upload) =>
          upload.kind == FollowUpUploadRecord.kindTarget &&
          upload.packageId == package.id &&
          (upload.serverStatus == 'refused' || upload.serverStatus == 'studio_rejected'),
    )
    .length;

/// Whether nothing is left to do for an annotation: its newest photograph, from
/// this package, was checked and is good. Waiting, weak or undone stays To do.
bool annotationIsDone(
  FollowUpPackage package,
  FollowUpAnnotation annotation,
  Iterable<FollowUpUploadRecord> uploads,
) {
  final photos = newPhotosOf(
    package,
    uploads,
    kind: FollowUpUploadRecord.kindAnnotation,
    itemKey: annotation.id.toString(),
  );
  if (photos.isEmpty) return false;
  return photos.first.serverStatus == 'kept' && photos.first.grade == 'ok';
}

/// Whether nothing is left to do for a target: its width is known, and either the
/// studio took a new photograph, or a measurement reached it with no photograph
/// on the way. A photograph turned down stays To do with its reason, until there
/// is a newer one, or someone measures it afterwards and so has moved on.
bool targetIsDone(
  FollowUpPackage package,
  FollowUpTarget target,
  Iterable<FollowUpUploadRecord> uploads,
) {
  if (currentTargetWidth(target, uploads, packageCreatedAt: package.createdAt) == null) {
    return false;
  }

  final photos = newPhotosOf(package, uploads, kind: FollowUpUploadRecord.kindTarget, itemKey: target.arKey);
  if (targetWasReplaced(photos)) return true;
  if (photos.any(_stillOnItsWay)) return false;

  final widths = newPhotosOf(package, uploads, kind: FollowUpUploadRecord.kindWidth, itemKey: target.arKey);
  if (widths.isEmpty || widths.first.serverStatus != 'pushed') return false;

  return photos.isEmpty || widths.first.createdAt.isAfter(photos.first.createdAt);
}

const _photoEndings = {'rejected', 'refused', 'superseded', 'studio_rejected', 'studio_approved'};

bool _stillOnItsWay(FollowUpUploadRecord photo) =>
    photo.status != FollowUpUploadRecord.statusFailed && !_photoEndings.contains(photo.serverStatus);
