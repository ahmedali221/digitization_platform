import 'package:digitization_platform/features/object_capture/domain/entities/scan_coverage.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/scan_plan.dart';
import 'package:digitization_platform/features/object_capture/domain/services/auto_shutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const still = 0.02;
  const walking = 0.4;
  const swinging = 1.5;

  CameraDirection facing(double azimuth, {double elevation = 0}) =>
      CameraDirection(azimuth: azimuth, elevation: elevation);

  ScanCoverage ringDone(int ring) => ScanCoverage({
    for (var sector = 0; sector < ScanPlan.rings[ring].sectors; sector++)
      ScanCell(ring, sector),
  });

  ScanGuidance guide(
    ScanCoverage coverage,
    CameraDirection direction, {
    double turningRate = still,
  }) => AutoShutter.guide(
    coverage: coverage,
    direction: direction,
    turningRate: turningRate,
  );

  group('where the camera is looking from', () {
    test(
      'a camera pointed level reads as level, one pointed down as above',
      () {
        expect(
          CameraDirection.fromForward(1, 0, 0).elevation,
          closeTo(0, 1e-9),
        );
        expect(
          CameraDirection.fromForward(0, 0, -1).elevation,
          closeTo(90, 1e-9),
        );
      },
    );

    test('turning to the left of the starting direction counts upwards', () {
      final start = CameraDirection.fromForward(1, 0, 0);
      final quarterTurn = CameraDirection.fromForward(0, 1, 0);

      expect(quarterTurn.azimuth - start.azimuth, closeTo(90, 1e-9));
    });
  });

  group('the plan', () {
    test('asks for forty photographs in two rings', () {
      expect(ScanPlan.totalCells, 40);
    });

    test('a slice is found from the angle round the object', () {
      expect(ScanPlan.cellAt(0, 0), const ScanCell(0, 0));
      expect(ScanPlan.cellAt(0, 14.9), const ScanCell(0, 0));
      expect(ScanPlan.cellAt(0, 15), const ScanCell(0, 1));
      expect(ScanPlan.cellAt(0, -1), const ScanCell(0, 23));
      expect(ScanPlan.cellAt(1, 359), const ScanCell(1, 15));
    });

    test('the ring is found from how far the camera looks down', () {
      expect(ScanPlan.ringAt(-10), 0);
      expect(ScanPlan.ringAt(24), 0);
      expect(ScanPlan.ringAt(25), 1);
      expect(ScanPlan.ringAt(80), 1);
    });
  });

  group('the auto shutter', () {
    test('shoots the first slice the moment the phone is still', () {
      expect(guide(const ScanCoverage(), facing(0)), ScanGuidance.shoot);
    });

    test('waits for the phone to settle before shooting', () {
      expect(
        guide(const ScanCoverage(), facing(0), turningRate: walking),
        ScanGuidance.holdStill,
      );
    });

    test('asks for a slower hand when the phone is swung round', () {
      expect(
        guide(const ScanCoverage(), facing(0), turningRate: swinging),
        ScanGuidance.slowDown,
      );
    });

    test('never shoots a slice twice, and sends the operator on instead', () {
      final coverage = const ScanCoverage().withCaptured(const ScanCell(0, 0));

      expect(guide(coverage, facing(5)), ScanGuidance.moveRight);
      expect(guide(coverage, facing(20)), ScanGuidance.shoot);
    });

    test('turns the operator back only when that saves a real walk', () {
      final coverage = ScanCoverage({
        for (var sector = 0; sector < 24; sector++)
          if (sector != 22) ScanCell(0, sector),
      });

      // slice 22 spans 330 to 345 degrees: left of the start, right of 300
      expect(guide(coverage, facing(2)), ScanGuidance.moveLeft);
      expect(guide(coverage, facing(300)), ScanGuidance.moveRight);
    });

    test('does not shoot while the phone is at the wrong height', () {
      expect(
        guide(const ScanCoverage(), facing(0, elevation: 40)),
        ScanGuidance.wrongHeight,
      );
      expect(guide(ringDone(0), facing(0)), ScanGuidance.wrongHeight);
      expect(guide(ringDone(0), facing(0, elevation: 40)), ScanGuidance.shoot);
    });

    test('is finished once every ring is done', () {
      final everything = ScanCoverage({
        ...ringDone(0).captured,
        ...ringDone(1).captured,
      });

      expect(everything.activeRing, isNull);
      expect(guide(everything, facing(0)), ScanGuidance.finished);
    });
  });

  group('coverage', () {
    test('an arc the server found empty is opened to be shot again', () {
      // the server saw nothing from 200 degrees round to the start
      final reopened = ringDone(
        0,
      ).reopened(const [CoverageGap(fromDegrees: 200, toDegrees: 0)]);

      expect(reopened.isCaptured(const ScanCell(0, 12)), isTrue);
      expect(reopened.isCaptured(const ScanCell(0, 14)), isFalse);
      expect(reopened.isCaptured(const ScanCell(0, 23)), isFalse);
      expect(reopened.isCaptured(const ScanCell(0, 0)), isTrue);
      expect(reopened.capturedIn(0), 13);
    });

    test('a gap that wraps the start is told from one that does not', () {
      const wrapping = CoverageGap(fromDegrees: 350, toDegrees: 20);

      expect(wrapping.contains(355), isTrue);
      expect(wrapping.contains(10), isTrue);
      expect(wrapping.contains(180), isFalse);
    });
  });
}
