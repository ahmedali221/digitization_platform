import '../../domain/entities/hall.dart';
import '../../domain/entities/new_item_draft.dart';
import '../../domain/entities/object_metadata.dart';
import '../../domain/entities/object_type.dart';

/// A wall or object an operator added on this phone — everything known
/// about it before (and until) a published package carries it back.
///
/// Stored as a plain map in the `unassigned` box, keyed by its `local_` id.
/// The box and the first five keys predate typed items, so a stub written by
/// an older build reads as a wall with no client id; [clientUuid] is minted
/// for those the first time they are sent.
class LocalItemStub {
  const LocalItemStub({
    required this.floorId,
    required this.name,
    required this.createdAt,
    this.notes = '',
    this.hallId,
    this.hallName,
    this.objectType = ObjectType.wall,
    this.captureMode = CaptureMode.grid,
    this.metadata = ObjectMetadata.empty,
    this.clientUuid,
    this.intakeStatus = IntakeStatus.accepted,
  });

  factory LocalItemStub.fromDraft({
    required String floorId,
    required NewItemDraft draft,
    required String clientUuid,
    required DateTime createdAt,
  }) {
    return LocalItemStub(
      floorId: floorId,
      name: draft.name,
      notes: draft.notes,
      createdAt: createdAt,
      hallId: draft.hall?.id,
      hallName: draft.hall?.name,
      objectType: draft.objectType,
      captureMode: draft.objectType.captureMode,
      metadata: draft.metadata,
      clientUuid: clientUuid,
    );
  }

  factory LocalItemStub.fromMap(Map<dynamic, dynamic> map) {
    final objectType = ObjectType.fromWire(map[_objectType] as String?);
    final storedCaptureMode = map[_captureMode] as String?;
    return LocalItemStub(
      floorId: map[_floorId] as String,
      name: map[_title] as String? ?? '',
      notes: map[_notes] as String? ?? '',
      createdAt:
          DateTime.tryParse(map[_createdAt] as String? ?? '') ?? DateTime.now(),
      hallId: map[_hallId] as String?,
      hallName: map[_roomLabel] as String?,
      objectType: objectType,
      captureMode: storedCaptureMode == null
          ? objectType.captureMode
          : CaptureMode.fromWire(storedCaptureMode),
      metadata: ObjectMetadata.fromWire(map[_metadata] as Map?),
      clientUuid: map[_clientUuid] as String?,
      intakeStatus: IntakeStatus.fromWire(map[_intakeStatus] as String?),
    );
  }

  static const _floorId = 'floorId';
  static const _title = 'title';
  static const _notes = 'notes';
  static const _createdAt = 'createdAt';
  static const _roomLabel = 'roomLabel';
  static const _hallId = 'hallId';
  static const _objectType = 'objectType';
  static const _captureMode = 'captureMode';
  static const _metadata = 'metadata';
  static const _clientUuid = 'clientUuid';
  static const _intakeStatus = 'intakeStatus';

  final String floorId;
  final String name;
  final String notes;
  final DateTime createdAt;
  final String? hallId;
  final String? hallName;
  final ObjectType objectType;
  final CaptureMode captureMode;
  final ObjectMetadata metadata;

  /// The id the server deduplicates this item on. Unlike the `local_` key,
  /// which is only unique on this phone, it is unique everywhere.
  final String? clientUuid;

  /// What the server answered when the item was sent; `accepted` until then.
  final IntakeStatus intakeStatus;

  HallEntity? get hall {
    final name = hallName?.trim() ?? '';
    return name.isEmpty ? null : HallEntity(id: hallId, name: name);
  }

  LocalItemStub copyWith({
    String? hallId,
    String? hallName,
    String? clientUuid,
    IntakeStatus? intakeStatus,
  }) {
    return LocalItemStub(
      floorId: floorId,
      name: name,
      notes: notes,
      createdAt: createdAt,
      hallId: hallId ?? this.hallId,
      hallName: hallName ?? this.hallName,
      objectType: objectType,
      captureMode: captureMode,
      metadata: metadata,
      clientUuid: clientUuid ?? this.clientUuid,
      intakeStatus: intakeStatus ?? this.intakeStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      _floorId: floorId,
      _title: name,
      _notes: notes,
      _createdAt: createdAt.toIso8601String(),
      _roomLabel: hallName,
      _hallId: hallId,
      _objectType: objectType.name,
      _captureMode: captureMode.name,
      _metadata: metadata.toWire(),
      _clientUuid: clientUuid,
      _intakeStatus: intakeStatus.name,
    }..removeWhere((_, value) => value == null);
  }
}
