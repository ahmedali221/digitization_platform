import 'dart:io';

import 'package:digitization_platform/core/data/repositories/fake_site_repository.dart';
import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/core/theme/wall_status.dart';
import 'package:digitization_platform/features/object_capture/data/datasources/object_scan_local_data_source.dart';
import 'package:digitization_platform/features/object_capture/data/datasources/object_scan_remote_data_source.dart';
import 'package:digitization_platform/features/object_capture/data/repositories/object_scan_repository_impl.dart';
import 'package:digitization_platform/features/object_capture/data/uploaders/object_scan_uploader.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/object_scan.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/scan_plan.dart';
import 'package:digitization_platform/features/object_capture/domain/entities/scan_preview.dart';
import 'package:digitization_platform/features/sync_queue/domain/entities/sync_item_kind.dart';
import 'package:digitization_platform/features/sync_queue/domain/repositories/sync_enqueuer.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../support/hive_harness.dart';
import '../../../support/temp_directory_manager.dart';

class _RecordingEnqueuer implements SyncEnqueuer {
  final List<({String wallId, SyncItemKind kind})> queued = [];

  @override
  Future<void> enqueueCapture({
    required String wallId,
    required String siteId,
    required String displayName,
    required SyncItemKind kind,
  }) async => queued.add((wallId: wallId, kind: kind));
}

void main() {
  final hive = HiveHarness();
  const floorId = 'f2';
  const serverWallId = '42';
  const serverScanId = 9;

  late TempDirectoryManager directories;
  late ObjectScanLocalDataSource local;
  late ObjectScanRepositoryImpl repository;
  late ObjectScanUploader uploader;
  late _RecordingEnqueuer enqueuer;
  late FakeSiteRepository sites;
  late String wallId;
  late List<RequestOptions> requests;

  /// What the server says when asked about the scan.
  late Map<String, dynamic> serverScan;

  /// The photograph upload whose turn this is fails with a dropped connection.
  int? failOnUploadNumber;

  const roughModel = 'bytes of a rough model';

  /// A rough model the server built from photographs 101 to 106, the level
  /// slices 0 to 5. Its angles start 97.5 degrees round from the phone's,
  /// and it lacks the side slice 2 was shot from.
  Map<String, dynamic> previewOf({String status = 'completed'}) => {
    'id': 31,
    'status': status,
    'progress': status == 'completed' ? 1 : 0.4,
    'model_url': status == 'completed' ? '/scans/9/preview' : null,
    'unseen_fraction': 0.12,
    'unseen': [
      {'azimuth': 300.0, 'elevation': 0.0, 'share': 0.12},
    ],
    'views': [
      for (var sector = 0; sector < 6; sector++)
        {
          'name': '0${101 + sector}.jpg',
          'azimuth': ScanPlan.normalise(
            ScanPlan.centreOf(ScanCell(0, sector)) - 97.5,
          ),
        },
    ],
  };

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    directories = await TempDirectoryManager.create();
    local = ObjectScanLocalDataSource(directoryManager: directories);
    enqueuer = _RecordingEnqueuer();
    sites = FakeSiteRepository();
    wallId = sites
        .findFloor(floorId)!
        .walls
        .firstWhere((wall) => wall.status == WallStatus.notStarted)
        .id;
    requests = [];
    failOnUploadNumber = null;
    serverScan = {'id': serverScanId, 'status': 'checking'};

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final uploads = requests.where((r) => r.data is FormData).length;
            if (options.data is FormData) {
              if (uploads == failOnUploadNumber) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
              }
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: <String, dynamic>{'sequence': 100 + uploads},
                ),
              );
            }
            if (options.path.endsWith('/preview')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: ResponseBody.fromString(roughModel, 200),
                ),
              );
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: serverScan,
              ),
            );
          },
        ),
      );
    final remote = ObjectScanRemoteDataSource(dio);

    repository = ObjectScanRepositoryImpl(
      siteRepository: sites,
      local: local,
      remote: remote,
      syncEnqueuer: enqueuer,
    );
    uploader = ObjectScanUploader(
      local: local,
      remote: remote,
      directoryManager: directories,
    );
  });

  tearDown(() => directories.dispose());

  /// Takes a photograph for [sector] of the level ring, as the camera would.
  Future<void> shoot(int sector, {int ring = 0}) async {
    final incoming = await repository.incomingFolder(wallId);
    final shot = File(p.join(incoming, 'shot_${ring}_$sector.jpg'));
    await shot.writeAsString('pixels of slice $ring/$sector');
    await repository.addShot(
      floorId: floorId,
      wallId: wallId,
      shotPath: shot.path,
      cell: ScanCell(ring, sector),
    );
  }

  Future<void> shootAndFinish(int count, {bool fullCircle = true}) async {
    for (var sector = 0; sector < count; sector++) {
      await shoot(sector);
    }
    await repository.finish(
      floorId: floorId,
      wallId: wallId,
      fullCircle: fullCircle,
    );
  }

  Future<void> upload({List<double>? progress}) => uploader.upload(
    localWallId: wallId,
    serverWallId: serverWallId,
    siteId: 's1',
    onProgress: (fraction) => progress?.add(fraction),
  );

  ObjectScan scan() => repository.getScan(wallId)!;

  test(
    'each photograph is kept under the scan with the slice it was taken for',
    () async {
      expect(repository.getScan(wallId), isNull);

      await shoot(0);
      await shoot(1);

      expect(scan().stage, ScanStage.capturing);
      expect(scan().coverage.captured, {
        const ScanCell(0, 0),
        const ScanCell(0, 1),
      });
      for (final shot in scan().shots) {
        expect(File(shot.path).existsSync(), isTrue);
        expect(p.basename(p.dirname(shot.path)), 'scan');
      }
      expect(
        Directory(await repository.incomingFolder(wallId)).listSync(),
        isEmpty,
      );
    },
  );

  test(
    'finishing queues the scan beside the photographs of the object, and shows work began',
    () async {
      await shootAndFinish(3);

      expect(enqueuer.queued, [
        (wallId: wallId, kind: SyncItemKind.objectScan),
      ]);
      expect(
        SyncItemKind.objectScan.queueId(wallId),
        isNot(SyncItemKind.objectPhotos.queueId(wallId)),
      );
      expect(scan().stage, ScanStage.uploading);
      expect(sites.findWall(floorId, wallId)!.status, WallStatus.inProgress);
    },
  );

  test('a scan with no photographs is not handed over', () async {
    await repository.finish(floorId: floorId, wallId: wallId, fullCircle: true);

    expect(enqueuer.queued, isEmpty);
    expect(uploader.hasCapture(wallId), isFalse);
  });

  test(
    'the upload starts the scan, sends each photograph, then has them confirmed',
    () async {
      await shootAndFinish(3, fullCircle: false);
      final progress = <double>[];

      await upload(progress: progress);

      expect(requests.map((r) => '${r.method} ${r.path}'), [
        'POST /walls/42/scans',
        'POST /scans/9/photos',
        'POST /scans/9/photos',
        'POST /scans/9/photos',
        'POST /scans/9/complete',
      ]);
      final start = requests.first.data as Map;
      expect(start['hints'], {'full_circle': false});
      expect(start['client_uuid'], hasLength(36));
      expect((requests.last.data as Map)['checksums'], hasLength(3));
      expect(progress.last, 1.0);
      expect(scan().stage, ScanStage.checking);
      expect(scan().uploadedCount, 3);
    },
  );

  test(
    'an upload cut off half-way resumes with the photographs still to go',
    () async {
      await shootAndFinish(3);
      failOnUploadNumber = 2;

      await expectLater(upload(), throwsA(isA<AppException>()));
      expect(scan().uploadedCount, 1);
      expect(scan().stage, ScanStage.uploading);

      failOnUploadNumber = null;
      requests.clear();
      await upload();

      expect(requests.where((r) => r.data is FormData), hasLength(2));
      expect(scan().stage, ScanStage.checking);
    },
  );

  test(
    'once the server has them, the photographs leave the phone but the scan stays',
    () async {
      await shootAndFinish(3);
      await upload();
      final paths = [for (final shot in scan().shots) shot.path];

      await uploader.deleteBackups(localWallId: wallId, siteId: 's1');

      expect(
        paths.map((path) => File(path).existsSync()),
        everyElement(isFalse),
      );
      expect(scan().coverage.capturedCount, 3);
    },
  );

  test('the answer of the server is read back into the scan', () async {
    await shootAndFinish(3);
    await upload();
    serverScan = {
      'id': serverScanId,
      'status': 'needs_more_photos',
      'coverage': {
        'verdict': 'needs_more_photos',
        'reasons': ['No photographs for 160 degrees round the object.'],
        'gaps': [
          {'from_degrees': 200.0, 'to_degrees': 0.0, 'width_degrees': 160.0},
        ],
        'unplaced_photos': ['0102.jpg'],
      },
      'run': {'kind': 'quick_check', 'status': 'completed', 'progress': 1},
    };

    await repository.refreshStatus(wallId);

    expect(scan().stage, ScanStage.needsMorePhotos);
    expect(scan().server!.reasons, [
      'No photographs for 160 degrees round the object.',
    ]);
    expect(scan().server!.gaps.single.contains(270), isTrue);
  });

  test(
    'reopening drops what the server could not use and keeps the rest',
    () async {
      // slices 0, 1 and 2 by the server's numbers 101, 102 and 103
      await shootAndFinish(3);
      await shoot(14);
      await repository.finish(
        floorId: floorId,
        wallId: wallId,
        fullCircle: true,
      );
      await upload();
      serverScan = {
        'id': serverScanId,
        'status': 'needs_more_photos',
        'coverage': {
          'gaps': [
            {'from_degrees': 200.0, 'to_degrees': 0.0},
          ],
          'unplaced_photos': ['0102.jpg'],
        },
      };
      await repository.refreshStatus(wallId);

      await repository.reopen(wallId);

      expect(scan().stage, ScanStage.capturing);
      expect(
        scan().coverage.captured,
        {const ScanCell(0, 0), const ScanCell(0, 2)},
        reason:
            'slice 1 could not be fitted, and slice 14 lies in the empty arc',
      );
      expect(scan().server, isNull);
    },
  );

  test(
    'reopening a scan the server gave no pointers for starts it over',
    () async {
      await shootAndFinish(3);
      await upload();
      serverScan = {
        'id': serverScanId,
        'status': 'needs_more_photos',
        'coverage': {
          'verdict': 'failed',
          'reasons': ['The photographs could not be fitted together.'],
        },
      };
      await repository.refreshStatus(wallId);

      await repository.reopen(wallId);

      expect(scan().shots, isEmpty);
      expect(scan().stage, ScanStage.capturing);
    },
  );

  test(
    'a scan less than half of which fitted together is shot again whole',
    () async {
      // as the first real scan came back: some placed, most not
      await shootAndFinish(4);
      await upload();
      serverScan = {
        'id': serverScanId,
        'status': 'needs_more_photos',
        'coverage': {
          'verdict': 'failed',
          'unplaced_photos': ['0103.jpg', '0104.jpg'],
        },
      };
      await repository.refreshStatus(wallId);

      await repository.reopen(wallId);

      expect(
        scan().shots,
        isEmpty,
        reason: 'the two that fitted are not a start worth keeping',
      );
    },
  );

  test('a photograph the server set aside as blurred is taken again', () async {
    await shootAndFinish(3);
    await upload();
    serverScan = {
      'id': serverScanId,
      'status': 'needs_more_photos',
      'coverage': {
        'verdict': 'needs_more_photos',
        'photos_set_aside': {
          '0102.jpg': ['blurry'],
        },
      },
    };
    await repository.refreshStatus(wallId);

    await repository.reopen(wallId);

    expect(scan().coverage.captured, {
      const ScanCell(0, 0),
      const ScanCell(0, 2),
    });
  });

  test('scanning again from the start gives up every photograph', () async {
    await shootAndFinish(3);
    await upload();
    serverScan = {'id': serverScanId, 'status': 'needs_more_photos'};
    await repository.refreshStatus(wallId);

    await repository.reopen(wallId, fromTheStart: true);

    expect(scan().shots, isEmpty);
    expect(scan().stage, ScanStage.capturing);
  });

  test('the rough model is followed while it is built, then fetched', () async {
    await shootAndFinish(6);
    await upload();
    serverScan = {
      'id': serverScanId,
      'status': 'needs_more_photos',
      'preview': previewOf(status: 'running'),
    };

    await repository.refreshStatus(wallId);

    expect(scan().server!.preview!.stage, ScanPreviewStage.building);
    expect(scan().server!.preview!.modelPath, isNull);
    expect(scan().isSettled, isFalse, reason: 'the model is still to come');

    serverScan = {
      'id': serverScanId,
      'status': 'needs_more_photos',
      'preview': previewOf(),
    };
    await repository.refreshStatus(wallId);
    await repository.refreshStatus(wallId);

    final preview = scan().server!.preview!;
    expect(preview.canBeShown, isTrue);
    expect(File(preview.modelPath!).readAsStringSync(), roughModel);
    expect(preview.unseenFraction, 0.12);
    expect(scan().isSettled, isTrue);
    expect(
      requests.where((r) => r.path.endsWith('/preview')),
      hasLength(1),
      reason: 'a model already here is not fetched again',
    );
  });

  test('going back for a hole in the rough model keeps every photograph and '
      'asks again for the side the hole is on', () async {
    await shootAndFinish(6);
    await upload();
    // the server found the scan complete, yet its rough model has a hole
    serverScan = {
      'id': serverScanId,
      'status': 'processing',
      'preview': previewOf(),
    };
    await repository.refreshStatus(wallId);
    final roughModelFile = scan().server!.preview!.modelPath!;

    expect(scan().missingParts, {const ScanCell(0, 2), const ScanCell(1, 1)});

    await repository.reopen(wallId);

    expect(scan().stage, ScanStage.capturing);
    expect(scan().shots, hasLength(6), reason: 'nothing is given up');
    expect(scan().coverage.isCaptured(const ScanCell(0, 2)), isFalse);
    expect(scan().coverage.capturedCount, 5);
    expect(File(roughModelFile).existsSync(), isFalse);

    await shoot(2);

    expect(scan().coverage.isCaptured(const ScanCell(0, 2)), isTrue);
    expect(scan().shots, hasLength(7));
  });
}
