// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_mapping_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdMappingRecordAdapter extends TypeAdapter<IdMappingRecord> {
  @override
  final int typeId = 3;

  @override
  IdMappingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IdMappingRecord(
      localId: fields[0] as String,
      wallId: fields[1] as String,
      resolvedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, IdMappingRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.wallId)
      ..writeByte(2)
      ..write(obj.resolvedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdMappingRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
