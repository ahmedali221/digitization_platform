// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_session_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CapturePhotoRecordAdapter extends TypeAdapter<CapturePhotoRecord> {
  @override
  final int typeId = 6;

  @override
  CapturePhotoRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CapturePhotoRecord(
      file: fields[0] as String,
      sha256: fields[1] as String,
      shot: fields[2] as int,
      capturedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CapturePhotoRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.file)
      ..writeByte(1)
      ..write(obj.sha256)
      ..writeByte(2)
      ..write(obj.shot)
      ..writeByte(3)
      ..write(obj.capturedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturePhotoRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CaptureCellRecordAdapter extends TypeAdapter<CaptureCellRecord> {
  @override
  final int typeId = 5;

  @override
  CaptureCellRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CaptureCellRecord(
      row: fields[0] as int,
      col: fields[1] as int,
      photos: (fields[2] as List).cast<CapturePhotoRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, CaptureCellRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.row)
      ..writeByte(1)
      ..write(obj.col)
      ..writeByte(2)
      ..write(obj.photos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureCellRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CaptureSessionRecordAdapter extends TypeAdapter<CaptureSessionRecord> {
  @override
  final int typeId = 4;

  @override
  CaptureSessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CaptureSessionRecord(
      sessionId: fields[0] as String,
      wallId: fields[1] as String,
      floorId: fields[2] as String,
      siteId: fields[3] as String,
      gridRows: fields[4] as int,
      gridCols: fields[5] as int,
      cells: (fields[6] as List).cast<CaptureCellRecord>(),
      state: fields[7] as String,
      createdAt: fields[8] as DateTime,
      completedAt: fields[9] as DateTime?,
      serverSessionId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CaptureSessionRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.wallId)
      ..writeByte(2)
      ..write(obj.floorId)
      ..writeByte(3)
      ..write(obj.siteId)
      ..writeByte(4)
      ..write(obj.gridRows)
      ..writeByte(5)
      ..write(obj.gridCols)
      ..writeByte(6)
      ..write(obj.cells)
      ..writeByte(7)
      ..write(obj.state)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.serverSessionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureSessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
