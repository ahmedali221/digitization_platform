import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_uploads.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/target_width.dart';
import 'package:flutter_test/flutter_test.dart';

const _package = FollowUpPackage(
  id: 7,
  siteId: '1',
  siteName: 'Karnak',
  createdAt: null,
  totalBytes: 0,
  annotations: [],
  targets: [],
  files: {},
);

const _target = FollowUpTarget(
  arKey: 'abcdefghij',
  label: 'Wall-1',
  description: null,
  wall: FollowUpWall(id: 1, name: 'North Wall'),
  imageKey: 'target-abcdefghij.jpg',
  videoFrameKey: null,
  hasVideo: false,
);

FollowUpUploadRecord _upload({
  String token = 't',
  String kind = FollowUpUploadRecord.kindTarget,
  String itemKey = 'abcdefghij',
  int packageId = 7,
  String? serverStatus,
  double? width,
}) => FollowUpUploadRecord(
  token: token,
  kind: kind,
  siteId: '1',
  packageId: packageId,
  itemKey: itemKey,
  label: 'Wall-1',
  filePath: 'x.jpg',
  sha256: 'abc',
  capturedAt: DateTime(2026),
  serverStatus: serverStatus,
  createdAt: DateTime(2026),
  physicalWidthM: width,
);

void main() {
  group('what counts as New', () {
    test('every photograph of this item from this package, in the order given', () {
      final photos = newPhotosOf(
        _package,
        [_upload(token: 'newer'), _upload(token: 'older')],
        kind: FollowUpUploadRecord.kindTarget,
        itemKey: 'abcdefghij',
      );

      expect(photos.map((p) => p.token), ['newer', 'older']);
    });

    test('not one from an earlier package: this one already shows anything approved', () {
      final photos = newPhotosOf(
        _package,
        [_upload(packageId: 6)],
        kind: FollowUpUploadRecord.kindTarget,
        itemKey: 'abcdefghij',
      );

      expect(photos, isEmpty);
    });

    test('not another item, nor a width sent for the same target', () {
      final photos = newPhotosOf(
        _package,
        [_upload(itemKey: 'other'), _upload(kind: FollowUpUploadRecord.kindWidth)],
        kind: FollowUpUploadRecord.kindTarget,
        itemKey: 'abcdefghij',
      );

      expect(photos, isEmpty);
    });
  });

  test('a target counts as replaced only once the studio has approved', () {
    expect(targetWasReplaced([_upload(serverStatus: 'pending_review')]), isFalse);
    expect(targetWasReplaced([_upload(serverStatus: 'pushed')]), isFalse);
    expect(targetWasReplaced([_upload(serverStatus: 'studio_rejected')]), isFalse);
    expect(targetWasReplaced([_upload(serverStatus: 'refused'), _upload(serverStatus: 'studio_approved')]), isTrue);
  });

  test('the banner counts what was turned down, from this package only', () {
    final uploads = [
      _upload(serverStatus: 'refused'),
      _upload(serverStatus: 'studio_rejected'),
      _upload(serverStatus: 'pending_review'),
      _upload(serverStatus: 'refused', packageId: 6),
      _upload(serverStatus: 'refused', kind: FollowUpUploadRecord.kindAnnotation),
    ];

    expect(turnedDownPhotos(_package, uploads), 2);
  });

  test('a width the studio has not taken is not the width in force', () {
    for (final status in ['refused', 'studio_rejected', 'held', 'kept']) {
      final upload = _upload(serverStatus: status, width: 1.42);
      expect(currentTargetWidth(_target, [upload]), isNull, reason: status);
    }
    expect(currentTargetWidth(_target, [_upload(serverStatus: 'pushed', width: 1.42)]), 1.42);
    expect(currentTargetWidth(_target, [_upload(serverStatus: 'studio_approved', width: 1.42)]), 1.42);
  });

  test('only target photographs are all kept when a newer one comes', () {
    expect(_upload().replacedByNewerOne, isFalse);
    expect(_upload(kind: FollowUpUploadRecord.kindAnnotation).replacedByNewerOne, isTrue);
    expect(_upload(kind: FollowUpUploadRecord.kindWidth).replacedByNewerOne, isTrue);
  });

  group('a grid counts as a photograph of its annotation', () {
    test('among what was sent for it', () {
      final grid = _upload(kind: FollowUpUploadRecord.kindAnnotationGrid, itemKey: '41');

      final photos = newPhotosOf(_package, [grid], kind: FollowUpUploadRecord.kindAnnotation, itemKey: '41');

      expect(photos, [grid]);
    });
  });

  group('annotationIsDone', () {
    const annotation = FollowUpAnnotation(
      id: 41,
      referenceCode: 'W-1',
      wall: FollowUpWall(id: 1, name: 'North Wall'),
      grade: 'weak',
      reasons: [],
      picture: null,
      polygon: [],
      closeupKey: null,
    );

    FollowUpUploadRecord photo(String? status, {String? grade, int packageId = 7, bool grid = false}) =>
        _upload(
          kind: grid ? FollowUpUploadRecord.kindAnnotationGrid : FollowUpUploadRecord.kindAnnotation,
          itemKey: '41',
          serverStatus: status,
          packageId: packageId,
        )..grade = grade;

    test('not with no photograph', () {
      expect(annotationIsDone(_package, annotation, []), isFalse);
    });

    test('once its newest is kept and good, as a photograph or a grid', () {
      expect(annotationIsDone(_package, annotation, [photo('kept', grade: 'ok')]), isTrue);
      expect(annotationIsDone(_package, annotation, [photo('kept', grade: 'ok', grid: true)]), isTrue);
    });

    test('not while anything is still to come of it', () {
      for (final status in [null, 'waiting_for_check', 'stitching', 'needs_decision', 'recheck_failed']) {
        expect(annotationIsDone(_package, annotation, [photo(status)]), isFalse, reason: '$status');
      }
    });

    test('not when weak, undone, or impossible to stitch', () {
      expect(annotationIsDone(_package, annotation, [photo('kept', grade: 'weak')]), isFalse);
      expect(annotationIsDone(_package, annotation, [photo('reverted', grade: 'ok')]), isFalse);
      expect(annotationIsDone(_package, annotation, [photo('stitch_failed', grid: true)]), isFalse);
      expect(annotationIsDone(_package, annotation, [photo('declined', grid: true)]), isFalse);
    });

    test('goes by the newest, so a worse retake puts it back', () {
      expect(
        annotationIsDone(_package, annotation, [photo('reverted'), photo('kept', grade: 'ok')]),
        isFalse,
      );
    });

    test('a photograph from an earlier package says nothing about this one', () {
      expect(annotationIsDone(_package, annotation, [photo('kept', grade: 'ok', packageId: 6)]), isFalse);
    });
  });

  group('targetIsDone', () {
    const measured = FollowUpTarget(
      arKey: 'abcdefghij',
      label: 'Wall-1',
      description: null,
      wall: null,
      imageKey: 'target-abcdefghij.jpg',
      videoFrameKey: null,
      hasVideo: false,
      physicalWidthM: 1.5,
    );

    FollowUpUploadRecord photo(String? status, {DateTime? at, String sendStatus = FollowUpUploadRecord.statusSent}) =>
        FollowUpUploadRecord(
          token: 'p',
          kind: FollowUpUploadRecord.kindTarget,
          siteId: '1',
          packageId: 7,
          itemKey: measured.arKey,
          label: 'Wall-1',
          filePath: 'x.jpg',
          sha256: 'abc',
          capturedAt: DateTime(2026),
          serverStatus: status,
          status: sendStatus,
          createdAt: at ?? DateTime(2026),
        );

    FollowUpUploadRecord width(String? status, {DateTime? at}) => FollowUpUploadRecord(
      token: 'w',
      kind: FollowUpUploadRecord.kindWidth,
      siteId: '1',
      packageId: 7,
      itemKey: measured.arKey,
      label: 'Wall-1',
      filePath: '',
      sha256: '',
      capturedAt: DateTime(2026),
      serverStatus: status,
      status: FollowUpUploadRecord.statusSent,
      createdAt: at ?? DateTime(2026),
      physicalWidthM: 1.42,
    );

    test('not with nothing done, even with a width already known', () {
      expect(targetIsDone(_package, measured, []), isFalse);
    });

    test('once the studio takes a new photograph', () {
      expect(targetIsDone(_package, measured, [photo('studio_approved')]), isTrue);
    });

    test('not with no width at all, whatever became of the photograph', () {
      expect(targetIsDone(_package, _target, [photo('studio_approved')]), isFalse);
    });

    test('not while a photograph is on its way, at any step', () {
      for (final status in [null, 'pending_review', 'approved', 'pushed', 'push_failed']) {
        expect(targetIsDone(_package, measured, [photo(status)]), isFalse, reason: '$status');
      }
      expect(
        targetIsDone(_package, measured, [photo(null, sendStatus: FollowUpUploadRecord.statusQueued)]),
        isFalse,
      );
    });

    test('a photograph turned down stays with its reason', () {
      for (final status in ['rejected', 'refused', 'studio_rejected']) {
        expect(targetIsDone(_package, measured, [photo(status)]), isFalse, reason: status);
      }
    });

    test('a measurement alone, once it reaches the studio', () {
      expect(targetIsDone(_package, measured, [width('pushed')]), isTrue);
    });

    test('not while the measurement is still going, or waits for a choice, or lost', () {
      for (final status in [null, 'pending_push', 'held', 'kept', 'push_failed']) {
        expect(targetIsDone(_package, measured, [width(status)]), isFalse, reason: '$status');
      }
    });

    test('a measurement does not finish a target with a photograph on its way', () {
      expect(targetIsDone(_package, measured, [width('pushed'), photo('pending_review')]), isFalse);
    });

    test('a measurement made after a photograph was turned down means someone moved on', () {
      final turnedDown = photo('studio_rejected', at: DateTime(2026, 1, 1));

      expect(targetIsDone(_package, measured, [width('pushed', at: DateTime(2026, 1, 2)), turnedDown]), isTrue);
      expect(
        targetIsDone(_package, measured, [
          photo('studio_rejected', at: DateTime(2026, 1, 3)),
          width('pushed', at: DateTime(2026, 1, 2)),
        ]),
        isFalse,
      );
    });
  });
}
