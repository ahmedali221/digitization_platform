import 'package:uuid/uuid.dart';

import '../../../../core/data/datasources/site_local_data_source.dart';
import '../../../../core/data/models/id_mapping_record.dart';
import '../../../../core/data/models/local_item_stub.dart';
import '../../../../core/domain/entities/wall.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/storage/device_id_provider.dart';
import '../../data/datasources/sync_remote_data_source.dart';

/// What the server knows a wall as, and whether it still wants its photos.
typedef ServerWall = ({String serverWallId, bool isArchived});

/// Turns the id this phone knows a wall by into the server's.
///
/// For a wall that came from a package the two are the same. For one created
/// here, the first call creates it on the server and remembers the answer;
/// the wall keeps its `local_` id on this phone, and only requests carry the
/// server's. That translation at the edge is what lets a capture started
/// offline upload with nothing for the operator to resolve.
class FieldItemRegistrar {
  FieldItemRegistrar({
    required SiteLocalDataSource siteLocal,
    required SyncRemoteDataSource remote,
    required DeviceIdProvider deviceIdProvider,
    Uuid uuid = const Uuid(),
  }) : _siteLocal = siteLocal,
       _remote = remote,
       _deviceIdProvider = deviceIdProvider,
       _uuid = uuid;

  final SiteLocalDataSource _siteLocal;
  final SyncRemoteDataSource _remote;
  final DeviceIdProvider _deviceIdProvider;
  final Uuid _uuid;

  /// Throws `AppException` when the item has to be created and cannot be.
  Future<ServerWall> serverWallFor(String wallId) async {
    if (!wallId.startsWith(WallEntity.localIdPrefix)) {
      return (serverWallId: wallId, isArchived: false);
    }

    final known = _siteLocal.getIdMapping(wallId);
    if (known != null) return (serverWallId: known.wallId, isArchived: false);

    final stub = _siteLocal.getLocalItem(wallId);
    if (stub == null) {
      throw const AppException(
        ValidationFailure(
          'This item was added on this phone, but its details are no longer '
          'here, so it cannot be sent.',
          {},
        ),
      );
    }

    return _register(wallId, stub);
  }

  Future<ServerWall> _register(String localId, LocalItemStub stub) async {
    // An item added by a build that predates direct creation has no client
    // id yet. It is stored before the request goes out: the server tells a
    // retry from a second item by this id alone, so a retry must reuse it.
    final isFromOldBuild = stub.clientUuid == null;
    final clientUuid = stub.clientUuid ?? _uuid.v4();
    if (isFromOldBuild) {
      await _siteLocal.putLocalItem(
        localId,
        stub.copyWith(clientUuid: clientUuid),
      );
    }

    final registration = await _remote.createFieldItem(
      floorId: stub.floorId,
      payload: <String, dynamic>{
        'client_uuid': clientUuid,
        'device_id': await _deviceIdProvider.getOrCreateDeviceId(),
        'object_type': stub.objectType.name,
        'name': stub.name,
        'notes': stub.notes.isEmpty ? null : stub.notes,
        // Both, on purpose: the id is from a package that may be days old,
        // and if that hall has since gone the server files the item by name
        // rather than refusing a capture nobody can retake.
        'chamber_id': int.tryParse(stub.hallId ?? ''),
        'chamber_name': stub.hallName,
        // Such an item may already sit in the dashboard's unassigned queue
        // under its local id; naming it lets the server close that entry.
        'legacy_local_id': isFromOldBuild ? localId : null,
        ...stub.metadata.toWire(),
      }..removeWhere((_, value) => value == null),
    );

    await _siteLocal.putLocalItem(
      localId,
      stub.copyWith(
        clientUuid: clientUuid,
        hallId: registration.hallId,
        hallName: registration.hallName,
        intakeStatus: registration.intakeStatus,
      ),
    );
    await _siteLocal.putIdMapping(
      IdMappingRecord(
        localId: localId,
        wallId: registration.serverWallId,
        resolvedAt: registration.createdAt,
      ),
    );

    return (
      serverWallId: registration.serverWallId,
      isArchived: registration.isArchived,
    );
  }
}
