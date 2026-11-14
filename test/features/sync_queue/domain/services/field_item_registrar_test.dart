import 'package:digitization_platform/core/data/datasources/site_local_data_source.dart';
import 'package:digitization_platform/core/data/models/id_mapping_record.dart';
import 'package:digitization_platform/core/domain/entities/hall.dart';
import 'package:digitization_platform/core/domain/entities/new_item_draft.dart';
import 'package:digitization_platform/core/domain/entities/object_metadata.dart';
import 'package:digitization_platform/core/domain/entities/object_type.dart';
import 'package:digitization_platform/core/errors/failure.dart';
import 'package:digitization_platform/core/storage/device_id_provider.dart';
import 'package:digitization_platform/core/storage/hive_boxes.dart';
import 'package:digitization_platform/features/sync_queue/data/datasources/sync_remote_data_source.dart';
import 'package:digitization_platform/features/sync_queue/domain/services/field_item_registrar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../support/hive_harness.dart';

void main() {
  final hive = HiveHarness();
  late SiteLocalDataSource siteLocal;
  late List<RequestOptions> requests;
  late FieldItemRegistrar registrar;

  /// What the server answers; a test replaces it to change the answer.
  late Map<String, dynamic> serverAnswer;

  /// Runs as each request arrives, before it is answered.
  void Function()? onRequest;

  setUpAll(hive.open);
  tearDownAll(hive.close);

  setUp(() async {
    await hive.reset();
    siteLocal = SiteLocalDataSource();
    requests = [];
    onRequest = null;
    serverAnswer = {
      'wall_id': 42,
      'chamber_id': 9,
      'chamber_name': 'Garden',
      'intake_status': 'pending',
      'is_archived': false,
      'created_at': '2026-11-13T10:00:00+00:00',
      'created': true,
    };

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            onRequest?.call();
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 201,
                data: serverAnswer,
              ),
            );
          },
        ),
      );

    registrar = FieldItemRegistrar(
      siteLocal: siteLocal,
      remote: SyncRemoteDataSource(dio),
      deviceIdProvider: DeviceIdProvider(),
    );
  });

  Future<String> addStatue({HallEntity? hall}) {
    return siteLocal.addLocalItem(
      floorId: '100',
      draft: NewItemDraft(
        name: 'Seated scribe',
        objectType: ObjectType.statue,
        notes: 'Left of the doorway',
        hall: hall,
        metadata: const ObjectMetadata(
          inventoryNumber: 'JE 30272',
          heightCm: 51,
        ),
      ),
    );
  }

  Map<String, dynamic> sentPayload() =>
      (requests.single.data as Map).cast<String, dynamic>();

  test('a wall from a package is already the server\'s', () async {
    final wall = await registrar.serverWallFor('41');

    expect(wall.serverWallId, '41');
    expect(wall.isArchived, isFalse);
    expect(requests, isEmpty);
  });

  test('an item added here is created on its floor, as it was entered', () async {
    final localId = await addStatue(
      hall: const HallEntity(id: '7', name: 'Hall 3'),
    );
    final clientUuid = siteLocal.getLocalItem(localId)!.clientUuid;

    final wall = await registrar.serverWallFor(localId);

    expect(wall.serverWallId, '42');
    expect(requests.single.path, '/floors/100/items');
    expect(sentPayload(), {
      'client_uuid': clientUuid,
      'device_id': await DeviceIdProvider().getOrCreateDeviceId(),
      'object_type': 'statue',
      'name': 'Seated scribe',
      'notes': 'Left of the doorway',
      'chamber_id': 7,
      'chamber_name': 'Hall 3',
      'inventory_number': 'JE 30272',
      'height_cm': 51.0,
    });
  });

  test('a hall named on the phone is sent by name alone', () async {
    final localId = await addStatue(hall: const HallEntity(name: 'Garden'));

    await registrar.serverWallFor(localId);

    expect(sentPayload()['chamber_name'], 'Garden');
    expect(sentPayload().containsKey('chamber_id'), isFalse);
  });

  test('the answer is remembered: id, hall, and where it stands', () async {
    final localId = await addStatue();

    await registrar.serverWallFor(localId);

    final mapping = siteLocal.getIdMapping(localId)!;
    expect(mapping.wallId, '42');
    expect(
      mapping.resolvedAt.isAtSameMomentAs(DateTime.utc(2026, 11, 13, 10)),
      isTrue,
      reason: 'the server\'s clock, which a package\'s published_at shares',
    );

    final stub = siteLocal.getLocalItem(localId)!;
    expect(stub.hallId, '9');
    expect(stub.hallName, 'Garden');
    expect(stub.intakeStatus, IntakeStatus.pending);
  });

  test('an item already sent is not sent again', () async {
    final localId = await addStatue();
    await registrar.serverWallFor(localId);
    requests.clear();

    final wall = await registrar.serverWallFor(localId);

    expect(wall.serverWallId, '42');
    expect(requests, isEmpty);
  });

  test('an item resolved by an older build goes to the wall it was given', () async {
    final localId = await addStatue();
    await siteLocal.putIdMapping(
      IdMappingRecord(
        localId: localId,
        wallId: '77',
        resolvedAt: DateTime.utc(2026, 11),
      ),
    );

    final wall = await registrar.serverWallFor(localId);

    expect(wall.serverWallId, '77');
    expect(requests, isEmpty);
  });

  test('a rejected item is reported as archived', () async {
    final localId = await addStatue();
    serverAnswer = {
      ...serverAnswer,
      'intake_status': 'rejected',
      'is_archived': true,
    };

    final wall = await registrar.serverWallFor(localId);

    expect(wall.isArchived, isTrue);
  });

  group('an item added by a build that predates direct creation', () {
    const localId = 'local_a1b2c3d4';

    setUp(() async {
      await Hive.box(HiveBoxes.unassigned).put(localId, {
        'floorId': '100',
        'title': 'North face',
        'notes': '',
        'createdAt': '2026-11-01T09:00:00.000',
        'roomLabel': 'J',
      });
    });

    test('is sent as a wall, named so the unassigned queue can close it', () async {
      await registrar.serverWallFor(localId);

      final payload = sentPayload();
      expect(payload['object_type'], 'wall');
      expect(payload['name'], 'North face');
      expect(payload['chamber_name'], 'J');
      expect(payload['legacy_local_id'], localId);
      expect(payload.containsKey('notes'), isFalse);
    });

    test('has its new id stored before the request, so a retry reuses it', () async {
      String? storedAtRequestTime;
      onRequest = () {
        storedAtRequestTime = siteLocal.getLocalItem(localId)!.clientUuid;
      };

      await registrar.serverWallFor(localId);

      expect(storedAtRequestTime, isNotNull);
      expect(sentPayload()['client_uuid'], storedAtRequestTime);
    });
  });

  test('an item whose details are gone cannot be sent, and says so', () async {
    expect(
      () => registrar.serverWallFor('local_deadbeef'),
      throwsA(
        isA<AppException>().having(
          (exception) => exception.failure,
          'failure',
          isA<ValidationFailure>(),
        ),
      ),
    );
  });
}
