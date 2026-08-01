// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unassigned_capture_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UnassignedCaptureRecordAdapter
    extends TypeAdapter<UnassignedCaptureRecord> {
  @override
  final int typeId = 8;

  @override
  UnassignedCaptureRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UnassignedCaptureRecord(
      localId: fields[0] as String,
      siteId: fields[1] as String,
      floorId: fields[2] as String,
      shots: (fields[3] as List).cast<String>(),
      checksums: (fields[4] as List).cast<String>(),
      createdAt: fields[5] as DateTime,
      syncStatus: fields[6] as String,
      lastSyncedAt: fields[7] as DateTime?,
      resolvedWallId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UnassignedCaptureRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.siteId)
      ..writeByte(2)
      ..write(obj.floorId)
      ..writeByte(3)
      ..write(obj.shots)
      ..writeByte(4)
      ..write(obj.checksums)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.syncStatus)
      ..writeByte(7)
      ..write(obj.lastSyncedAt)
      ..writeByte(8)
      ..write(obj.resolvedWallId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnassignedCaptureRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
