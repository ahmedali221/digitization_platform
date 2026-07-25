// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_item_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncQueueItemRecordAdapter extends TypeAdapter<SyncQueueItemRecord> {
  @override
  final int typeId = 7;

  @override
  SyncQueueItemRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncQueueItemRecord(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      wallId: fields[2] as String,
      siteId: fields[3] as String,
      displayName: fields[4] as String,
      status: fields[5] as String,
      progress: fields[6] as int,
      attempts: fields[7] as int,
      lastError: fields[8] as String?,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueItemRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.wallId)
      ..writeByte(3)
      ..write(obj.siteId)
      ..writeByte(4)
      ..write(obj.displayName)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.progress)
      ..writeByte(7)
      ..write(obj.attempts)
      ..writeByte(8)
      ..write(obj.lastError)
      ..writeByte(9)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueItemRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
