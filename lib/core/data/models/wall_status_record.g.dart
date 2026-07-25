// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wall_status_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WallStatusRecordAdapter extends TypeAdapter<WallStatusRecord> {
  @override
  final int typeId = 2;

  @override
  WallStatusRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WallStatusRecord(
      wallId: fields[0] as String,
      status: fields[1] as String,
      dirty: fields[2] as bool,
      updatedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WallStatusRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.wallId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.dirty)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallStatusRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
