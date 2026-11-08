import 'dart:convert';

import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/features/follow_up/data/datasources/follow_up_remote_data_source.dart';
import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

FollowUpUploadRecord _newTarget() => FollowUpUploadRecord(
  token: 'the-token',
  kind: FollowUpUploadRecord.kindNewTarget,
  siteId: '3',
  packageId: 7,
  itemKey: 'W-12-A',
  label: 'W-12-A',
  filePath: 'the-token.jpg',
  sha256: 'abc',
  capturedAt: DateTime.utc(2026, 11, 7, 9, 30),
  createdAt: DateTime.utc(2026, 11, 7, 9, 30),
  physicalWidthM: 1.425,
  widthSource: 'ar',
  description: 'A procession of offering bearers.',
);

void main() {
  test('a new target goes to its site with its code, description, width and photograph', () async {
    final imageBytes = utf8.encode('jpeg bytes');
    final dio = Dio();
    RequestOptions? sent;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent = options;
          handler.resolve(Response<void>(requestOptions: options, statusCode: 201));
        },
      ),
    );

    await FollowUpRemoteDataSource(dio).uploadNewTarget(
      _newTarget(),
      openBytes: () => Stream.value(imageBytes),
      length: imageBytes.length,
    );

    final body = sent!.data as FormData;
    final photo = body.files.single;
    final photoBytes = await photo.value.finalize().fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));

    expect(sent!.path, '/sites/3/new-targets');
    expect(sent!.method, 'POST');
    expect(photo.key, 'capture');
    expect(photo.value.filename, 'the-token.jpg');
    expect(photoBytes, imageBytes);
    expect(Map<String, String>.fromEntries(body.fields), {
      'client_token': 'the-token',
      'sha256': 'abc',
      'package_id': '7',
      'captured_at': '2026-11-07T09:30:00.000Z',
      'wall_label': 'W-12-A',
      'description': 'A procession of offering bearers.',
      'physical_width_m': '1.425',
      'width_source': 'ar',
    });
  });

  test('a refusal comes back as a failure the runner can read', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 422,
              data: {
                'message': 'The code W-12-A is already used.',
                'errors': {
                  'wall_label': ['The code W-12-A is already used.'],
                },
              },
            ),
          ),
        ),
      ),
    );

    await expectLater(
      FollowUpRemoteDataSource(dio).uploadNewTarget(
        _newTarget(),
        openBytes: () => Stream.value(const [1]),
        length: 1,
      ),
      throwsA(isA<AppException>().having((e) => e.failure, 'failure', isA<ValidationFailure>())),
    );
  });
}
