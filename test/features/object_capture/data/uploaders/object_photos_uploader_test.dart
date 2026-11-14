import 'dart:io';

import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/features/object_capture/data/datasources/object_capture_local_data_source.dart';
import 'package:digitization_platform/features/object_capture/data/datasources/object_capture_remote_data_source.dart';
import 'package:digitization_platform/features/object_capture/data/models/object_capture_record.dart';
import 'package:digitization_platform/features/object_capture/data/uploaders/object_photos_uploader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../../support/hive_harness.dart';
import '../../../../support/temp_directory_manager.dart';

void main() {
  final hive = HiveHarness();
  late TempDirectoryManager directories;
  late ObjectCaptureLocalDataSource local;
  late ObjectPhotosUploader uploader;
  late List<RequestOptions> requests;

  /// The upload whose turn this is fails with a dropped connection.
  int? failOnUploadNumber;

  const localWallId = 'local_a1b2c3d4';
  const serverWallId = '42';

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    directories = await TempDirectoryManager.create();
    local = ObjectCaptureLocalDataSource(directoryManager: directories);
    requests = [];
    failOnUploadNumber = null;

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final isUpload = options.data is FormData;
            final uploadNumber = requests
                .where((request) => request.data is FormData)
                .length;
            if (isUpload && uploadNumber == failOnUploadNumber) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 201),
            );
          },
        ),
      );

    uploader = ObjectPhotosUploader(
      local: local,
      remote: ObjectCaptureRemoteDataSource(dio),
      directoryManager: directories,
    );
  });

  tearDown(() => directories.dispose());

  Future<ObjectPhotoRecord> photo(
    String name, {
    String? side,
    String? comment,
    bool uploaded = false,
  }) async {
    final folder = await directories.sessionDir(localWallId);
    final file = File(p.join(folder.path, '$name.jpg'));
    await file.writeAsString('bytes of $name');
    return ObjectPhotoRecord(
      file: file.path,
      sha256: 'sha-$name',
      capturedAt: DateTime.utc(2026, 11, 13, 9),
      side: side,
      comment: comment,
      uploaded: uploaded,
    );
  }

  Future<void> store(List<ObjectPhotoRecord> photos) {
    return local.put(
      ObjectCaptureRecord(
        wallId: localWallId,
        floorId: '100',
        siteId: '1',
        photos: photos,
        createdAt: DateTime.utc(2026, 11, 13),
      ),
    );
  }

  Future<void> upload({List<double>? progress}) {
    return uploader.upload(
      localWallId: localWallId,
      serverWallId: serverWallId,
      siteId: '1',
      onProgress: (fraction) => progress?.add(fraction),
    );
  }

  Map<String, String> fieldsOf(RequestOptions request) =>
      Map.fromEntries((request.data as FormData).fields);

  test('there is something to send only once a photograph is held', () async {
    expect(uploader.hasCapture(localWallId), isFalse);

    await store([]);
    expect(uploader.hasCapture(localWallId), isFalse);

    await store([await photo('front', side: 'front')]);
    expect(uploader.hasCapture(localWallId), isTrue);
  });

  test(
    'each photograph goes to the server\'s wall with its side or description',
    () async {
      await store([
        await photo('front', side: 'front'),
        await photo('detail', comment: 'Cartouche on the belt'),
      ]);
      final progress = <double>[];

      await upload(progress: progress);

      expect(requests.map((request) => request.path), [
        '/walls/42/object-photos',
        '/walls/42/object-photos',
        '/walls/42/object-photos/complete',
      ]);
      expect(fieldsOf(requests[0]), {
        'sha256': 'sha-front',
        'captured_at': '2026-11-13T09:00:00.000Z',
        'side': 'front',
      });
      expect(fieldsOf(requests[1]), {
        'sha256': 'sha-detail',
        'captured_at': '2026-11-13T09:00:00.000Z',
        'comment': 'Cartouche on the belt',
      });
      expect((requests[0].data as FormData).files.single.key, 'photo');
      expect(progress, [0.5, 1.0]);
    },
  );

  test(
    'the server is asked to confirm every photograph the phone holds',
    () async {
      await store([
        await photo('front', side: 'front', uploaded: true),
        await photo('back', side: 'back'),
      ]);

      await upload();

      expect(requests.last.data, {
        'checksums': ['sha-front', 'sha-back'],
      });
    },
  );

  test('a photograph already sent is not sent again', () async {
    await store([
      await photo('front', side: 'front', uploaded: true),
      await photo('back', side: 'back'),
    ]);

    await upload();

    final uploads = requests.where((request) => request.data is FormData);
    expect(uploads.map((request) => fieldsOf(request)['sha256']), ['sha-back']);
    expect(local.get(localWallId)!.photos.every((p) => p.uploaded), isTrue);
  });

  test(
    'an upload cut off half-way resumes with the photographs still to go',
    () async {
      await store([
        await photo('front', side: 'front'),
        await photo('back', side: 'back'),
        await photo('left', side: 'left'),
      ]);
      failOnUploadNumber = 2;

      await expectLater(
        upload(),
        throwsA(
          isA<AppException>().having(
            (exception) => exception.failure,
            'failure',
            isA<NetworkFailure>(),
          ),
        ),
      );
      expect(local.get(localWallId)!.photos.map((p) => p.uploaded), [
        true,
        false,
        false,
      ]);

      failOnUploadNumber = null;
      requests.clear();
      await upload();

      final uploads = requests.where((request) => request.data is FormData);
      expect(uploads.map((request) => fieldsOf(request)['sha256']), [
        'sha-back',
        'sha-left',
      ]);
      expect(requests.last.path, '/walls/42/object-photos/complete');
    },
  );

  test('backups go only when asked, and only this object\'s', () async {
    final backup = await directories.backupDir(localWallId);
    await File(p.join(backup.path, 'front.jpg')).writeAsString('copy');
    final other = await directories.backupDir('41');

    await uploader.deleteBackups(localWallId: localWallId, siteId: '1');

    expect(backup.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });
}
