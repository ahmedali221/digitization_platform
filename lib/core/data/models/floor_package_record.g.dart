// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floor_package_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FloorPackageRecordAdapter extends TypeAdapter<FloorPackageRecord> {
  @override
  final int typeId = 1;

  @override
  FloorPackageRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FloorPackageRecord(
      floorId: fields[0] as String,
      siteId: fields[1] as String,
      raw: (fields[2] as Map).cast<dynamic, dynamic>(),
      downloadedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FloorPackageRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.floorId)
      ..writeByte(1)
      ..write(obj.siteId)
      ..writeByte(2)
      ..write(obj.raw)
      ..writeByte(3)
      ..write(obj.downloadedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloorPackageRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
