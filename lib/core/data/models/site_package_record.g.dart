// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site_package_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SitePackageRecordAdapter extends TypeAdapter<SitePackageRecord> {
  @override
  final int typeId = 0;

  @override
  SitePackageRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SitePackageRecord(
      siteId: fields[0] as String,
      name: fields[1] as String,
      location: fields[2] as String?,
      latestVersion: fields[3] as int?,
      latestPublishedAt: fields[4] as DateTime?,
      raw: (fields[5] as Map?)?.cast<dynamic, dynamic>(),
      localVersion: fields[6] as int?,
      downloadedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SitePackageRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.siteId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.latestVersion)
      ..writeByte(4)
      ..write(obj.latestPublishedAt)
      ..writeByte(5)
      ..write(obj.raw)
      ..writeByte(6)
      ..write(obj.localVersion)
      ..writeByte(7)
      ..write(obj.downloadedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SitePackageRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
