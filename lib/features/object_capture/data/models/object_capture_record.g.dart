// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'object_capture_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ObjectPhotoRecordAdapter extends TypeAdapter<ObjectPhotoRecord> {
  @override
  final int typeId = 14;

  @override
  ObjectPhotoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ObjectPhotoRecord(
      file: fields[0] as String,
      sha256: fields[1] as String,
      capturedAt: fields[2] as DateTime,
      side: fields[3] as String?,
      comment: fields[4] as String?,
      uploaded: fields[5] == null ? false : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ObjectPhotoRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.file)
      ..writeByte(1)
      ..write(obj.sha256)
      ..writeByte(2)
      ..write(obj.capturedAt)
      ..writeByte(3)
      ..write(obj.side)
      ..writeByte(4)
      ..write(obj.comment)
      ..writeByte(5)
      ..write(obj.uploaded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectPhotoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ObjectCaptureRecordAdapter extends TypeAdapter<ObjectCaptureRecord> {
  @override
  final int typeId = 13;

  @override
  ObjectCaptureRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ObjectCaptureRecord(
      wallId: fields[0] as String,
      floorId: fields[1] as String,
      siteId: fields[2] as String,
      photos: (fields[3] as List).cast<ObjectPhotoRecord>(),
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ObjectCaptureRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.wallId)
      ..writeByte(1)
      ..write(obj.floorId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.photos)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectCaptureRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
