import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/follow_up_package.dart';
import 'package:digitization_platform/features/follow_up/domain/entities/target_width.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what someone typed', () {
    test('reads metres, with a decimal point or comma', () {
      expect(TargetWidth.parseMeters('1.42'), 1.42);
      expect(TargetWidth.parseMeters(' 1,42 '), 1.42);
      expect(TargetWidth.parseMeters('2'), 2);
    });

    test('reads the digits an Arabic keyboard offers', () {
      expect(TargetWidth.parseMeters('١٫٤٢'), 1.42);
      expect(TargetWidth.parseMeters('۲٫۵'), 2.5);
    });

    test('refuses what Thoth would silently drop, and what is not a number', () {
      for (final bad in ['', '0', '0.009', '100.1', '-1', 'wide', '1.4.2']) {
        expect(TargetWidth.parseMeters(bad), isNull, reason: bad);
      }
      expect(TargetWidth.parseMeters('0.01'), 0.01);
      expect(TargetWidth.parseMeters('100'), 100);
    });
  });

  group('the width a target has on this phone', () {
    final builtAt = DateTime(2026, 11, 5, 12);

    FollowUpTarget target({double? width}) => FollowUpTarget(
      arKey: 'abcdefghij',
      label: 'Wall-1',
      description: null,
      wall: const FollowUpWall(id: 1, name: 'North Wall'),
      imageKey: 'target-abcdefghij.jpg',
      videoFrameKey: null,
      hasVideo: false,
      physicalWidthM: width,
    );

    FollowUpUploadRecord upload({
      String kind = FollowUpUploadRecord.kindWidth,
      String itemKey = 'abcdefghij',
      double? width = 1.42,
      String status = FollowUpUploadRecord.statusSent,
      String? serverStatus,
      DateTime? createdAt,
    }) {
      final at = createdAt ?? DateTime(2026, 11, 5, 13);
      return FollowUpUploadRecord(
        token: 't',
        kind: kind,
        siteId: '1',
        packageId: 1,
        itemKey: itemKey,
        label: 'Wall-1',
        filePath: '',
        sha256: '',
        capturedAt: at,
        status: status,
        serverStatus: serverStatus,
        createdAt: at,
        physicalWidthM: width,
      );
    }

    double? current(FollowUpTarget t, List<FollowUpUploadRecord> uploads) =>
        currentTargetWidth(t, uploads, packageCreatedAt: builtAt);

    test('nothing known means missing', () {
      expect(current(target(), const []), isNull);
    });

    test('the package says what the dashboard knew', () {
      expect(current(target(width: 2), const []), 2);
    });

    test('a width still waiting to be sent already counts, with no signal', () {
      expect(current(target(), [upload(status: FollowUpUploadRecord.statusQueued)]), 1.42);
    });

    test('a photograph sent with a width counts while it waits for review', () {
      final photo = upload(kind: FollowUpUploadRecord.kindTarget, serverStatus: 'pending_review');
      expect(current(target(), [photo]), 1.42);
    });

    test('a refused width does not count, so the label comes back', () {
      expect(current(target(), [upload(status: FollowUpUploadRecord.statusFailed)]), isNull);
    });

    test('a rejected or replaced photograph does not count', () {
      for (final status in ['rejected', 'superseded']) {
        final photo = upload(kind: FollowUpUploadRecord.kindTarget, serverStatus: status);
        expect(current(target(width: 2), [photo]), 2, reason: status);
      }
    });

    test('the newest one wins', () {
      expect(current(target(), [upload(width: 1.5), upload(width: 1.42)]), 1.5);
    });

    test('a package built after an upload is newer: the reviewer may have corrected it', () {
      final older = upload(createdAt: DateTime(2026, 11, 5, 9));
      expect(current(target(width: 1.3), [older]), 1.3);
    });

    test('an older upload still counts if that package has nothing', () {
      final older = upload(createdAt: DateTime(2026, 11, 5, 9));
      expect(current(target(), [older]), 1.42);
    });

    test('another target, and an annotation, have nothing to say about it', () {
      expect(current(target(), [upload(itemKey: 'other')]), isNull);
      expect(current(target(), [upload(kind: FollowUpUploadRecord.kindAnnotation)]), isNull);
    });
  });
}
