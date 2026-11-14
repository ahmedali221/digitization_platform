import 'dart:async';

import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/object_scan.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/scan_plan.dart';
import 'package:digitization_platform/features/object_capture/domain/repositories/object_scan_repository.dart';
import 'package:digitization_platform/features/object_capture/domain/services/auto_shutter.dart';
import 'package:digitization_platform/features/object_capture/domain/services/camera_motion_source.dart';
import 'package:digitization_platform/features/object_capture/presentation/cubit/scan_capture_cubit.dart';
import 'package:digitization_platform/features/object_capture/presentation/cubit/scan_capture_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scan kept in memory, recording what the cubit asked of it.
class _InMemoryScans implements ObjectScanRepository {
  ObjectScan? scan;
  bool refuseShots = false;
  bool? finishedFullCircle;

  @override
  ObjectScan? getScan(String wallId) => scan;

  @override
  Stream<ObjectScan?> watchScan(String wallId) => Stream.value(scan);

  @override
  Future<String> incomingFolder(String wallId) async => '/incoming';

  @override
  Future<void> addShot({
    required String floorId,
    required String wallId,
    required String shotPath,
    required ScanCell cell,
  }) async {
    if (refuseShots) throw const FormatException('disk full');
    scan = ObjectScan(
      shots: [
        ...?scan?.shots,
        ScanShot(path: shotPath, cell: cell),
      ],
    );
  }

  @override
  Future<void> finish({
    required String floorId,
    required String wallId,
    required bool fullCircle,
  }) async => finishedFullCircle = fullCircle;

  @override
  Future<void> reopen(String wallId, {bool fromTheStart = false}) async {}

  @override
  Future<void> refreshStatus(String wallId) async {}
}

class _RecordedMotion implements CameraMotionSource {
  final controller = StreamController<CameraMotion>();

  @override
  Stream<CameraMotion> watch() => controller.stream;
}

void main() {
  const floorId = 'f2';
  const still = 0.02;
  const walking = 0.4;

  /// Time between two readings of the sensors in these tests: longer than
  /// the pause the shutter waits for, so the second still reading in a row
  /// is one the phone has settled by.
  const betweenReadings = Duration(milliseconds: 500);

  late _InMemoryScans scans;
  late _RecordedMotion motion;
  late FakeSiteRepository sites;
  late String wallId;
  late DateTime now;
  ScanCaptureCubit? cubit;

  setUp(() {
    scans = _InMemoryScans();
    motion = _RecordedMotion();
    sites = FakeSiteRepository();
    wallId = sites.findFloor(floorId)!.walls.first.id;
    now = DateTime(2026, 11, 14, 12);
  });

  tearDown(() async => cubit?.close());

  /// One reading of the sensors: the phone points [azimuth] degrees round,
  /// by their own count, which starts wherever it likes.
  Future<void> point(
    double azimuth, {
    double elevation = 0,
    double turningRate = still,
  }) async {
    now = now.add(betweenReadings);
    motion.controller.add(
      CameraMotion(
        direction: CameraDirection(azimuth: azimuth, elevation: elevation),
        turningRate: turningRate,
      ),
    );
    await pumpEventQueue();
  }

  /// The phone arrives at [azimuth] and is held there until it has settled.
  Future<void> hold(double azimuth, {double elevation = 0}) async {
    await point(azimuth, elevation: elevation, turningRate: walking);
    await point(azimuth, elevation: elevation);
    await point(azimuth, elevation: elevation);
  }

  ScanCaptureCubit open({String? wall}) => cubit = ScanCaptureCubit(
    scans,
    sites,
    motion,
    floorId: floorId,
    wallId: wall ?? wallId,
    clock: () => now,
  )..setCameraReady(true);

  /// Opens the scan screen and starts, with the sensors reading [heading].
  Future<ScanCaptureCubit> start({double heading = 0}) async {
    final cubit = open();
    await point(heading, turningRate: walking);
    cubit.begin();
    return cubit;
  }

  /// Holds the phone at [azimuth] and answers the photograph asked for.
  Future<void> holdAndShoot(
    ScanCaptureCubit cubit,
    double azimuth, {
    double elevation = 0,
  }) async {
    final before = cubit.state.shotRequest;
    await hold(azimuth, elevation: elevation);
    if (cubit.state.shotRequest != before) await cubit.shotTaken('/shot.jpg');
  }

  test('nothing is photographed until the operator starts the scan', () async {
    final cubit = open();
    expect(cubit.state.phase, ScanCapturePhase.ready);

    await hold(212);
    expect(cubit.state.shotRequest, 0);

    cubit.begin();
    await hold(212);
    expect(cubit.state.shotRequest, 1);
  });

  test('a camera that is still starting is waited for, not blamed', () async {
    final cubit = await start();
    cubit.setCameraReady(false);

    await hold(0);
    expect(cubit.state.shotRequest, 0);
    expect(cubit.state.failure, isNull);

    cubit.setCameraReady(true);
    await point(0);
    expect(cubit.state.shotRequest, 1);
  });

  test('the shutter waits for the phone to settle, not just to stop', () async {
    final cubit = await start(heading: 212);

    await point(212, turningRate: walking);
    expect(cubit.state.guidance, ScanGuidance.holdStill);

    await point(212);
    expect(cubit.state.shotRequest, 0, reason: 'it has only just stopped');

    await point(212);
    expect(cubit.state.shotRequest, 1);
  });

  test('a wobble starts the wait again', () async {
    final cubit = await start();

    await point(0);
    await point(0, turningRate: walking);
    await point(0);
    expect(cubit.state.shotRequest, 0);

    await point(0);
    expect(cubit.state.shotRequest, 1);
  });

  test(
    'angles are counted from where the scan began, not from the sensors',
    () async {
      final cubit = await start(heading: 212);

      await holdAndShoot(cubit, 212);
      await holdAndShoot(cubit, 212 + 20);

      expect(cubit.state.azimuth, 20);
      expect(cubit.state.coverage.captured, {
        const ScanCell(0, 0),
        const ScanCell(0, 1),
      });
      expect(scans.scan!.shots, hasLength(2));
    },
  );

  test('one photograph is asked for at a time', () async {
    final cubit = await start();

    await hold(0);
    await point(1);
    expect(
      cubit.state.shotRequest,
      1,
      reason: 'the first is still being taken',
    );

    await cubit.shotTaken('/shot.jpg');
    await point(1);
    expect(cubit.state.shotRequest, 1, reason: 'this slice is done');
    expect(cubit.state.guidance, ScanGuidance.moveRight);
  });

  test('a photograph that could not be kept is asked for again', () async {
    final cubit = await start();
    scans.refuseShots = true;

    await hold(0);
    await cubit.shotTaken('/shot.jpg');

    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.coverage.capturedCount, 0);

    scans.refuseShots = false;
    await holdAndShoot(cubit, 0);
    expect(cubit.state.coverage.capturedCount, 1);
  });

  test(
    'a scan with photographs is continued only from where it began',
    () async {
      scans.scan = const ObjectScan(
        shots: [ScanShot(path: '/a.jpg', cell: ScanCell(0, 0))],
      );
      final cubit = open();
      expect(cubit.state.phase, ScanCapturePhase.aligning);

      await hold(80);
      expect(
        cubit.state.shotRequest,
        0,
        reason: 'nothing is shot before aligning',
      );

      cubit.begin();
      await point(80);
      expect(
        cubit.state.azimuth,
        0,
        reason: 'where the operator stands is the start again',
      );
      expect(cubit.state.guidance, ScanGuidance.moveRight);

      await holdAndShoot(cubit, 80 + 16);
      expect(cubit.state.coverage.capturedCount, 2);
    },
  );

  test('the scan hands itself over when every slice is taken', () async {
    final cubit = await start();

    for (var sector = 0; sector < ScanPlan.rings[0].sectors; sector++) {
      await holdAndShoot(cubit, sector * 15 + 1);
    }
    expect(cubit.state.phase, ScanCapturePhase.scanning);
    expect(cubit.state.coverage.activeRing, 1);

    for (var sector = 0; sector < ScanPlan.rings[1].sectors; sector++) {
      await holdAndShoot(cubit, sector * 22.5 + 1, elevation: 40);
    }

    expect(cubit.state.phase, ScanCapturePhase.finished);
    expect(scans.finishedFullCircle, isTrue);
    expect(scans.scan!.shots, hasLength(ScanPlan.totalCells));
  });

  test(
    'finishing with the level ring open says the object was not walked round',
    () async {
      final cubit = await start();
      for (var sector = 0; sector < 14; sector++) {
        await holdAndShoot(cubit, sector * 15 + 1);
      }

      await cubit.finish();

      expect(cubit.state.phase, ScanCapturePhase.finished);
      expect(scans.finishedFullCircle, isFalse);
    },
  );

  test(
    'a phone without motion sensors is told apart from one that is waiting',
    () async {
      final cubit = open();

      motion.controller.addError(StateError('unavailable'));
      await pumpEventQueue();

      expect(cubit.state.phase, ScanCapturePhase.noSensors);
    },
  );

  test('an object that is no longer there has no scan screen', () {
    expect(open(wall: 'gone').state.phase, ScanCapturePhase.objectMissing);
  });
}
