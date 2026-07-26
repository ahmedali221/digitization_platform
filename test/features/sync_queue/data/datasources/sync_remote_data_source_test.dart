import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digitization_platform/features/sync_queue/data/datasources/sync_remote_data_source.dart';

void main() {
  test('uploadCellPhoto sends the image bytes as a multipart file', () async {
    final imageBytes = utf8.encode('actual image bytes');
    final dio = Dio();
    FormData? requestBody;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = options.data as FormData;
          handler.resolve(
            Response<void>(requestOptions: options, statusCode: 201),
          );
        },
      ),
    );

    await SyncRemoteDataSource(dio).uploadCellPhoto(
      wallId: '42',
      row: 1,
      col: 2,
      shot: 3,
      openImageBytes: () => Stream.value(imageBytes),
      imageLength: imageBytes.length,
      fileName: 'R2C3_S3.jpg',
    );

    final body = requestBody!;
    final uploadedImage = body.files.single;
    final uploadedBytes = await uploadedImage.value.finalize().fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );

    expect(uploadedImage.key, 'photos[]');
    expect(uploadedImage.value.filename, 'R2C3_S3.jpg');
    expect(uploadedBytes, imageBytes);
    expect(Map<String, String>.fromEntries(body.fields), {
      'row': '1',
      'col': '2',
      'shot': '3',
    });
  });
}
