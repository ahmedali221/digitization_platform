// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'object_scan_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanShotRecordAdapter extends TypeAdapter<ScanShotRecord> {
  @override
  final int typeId = 16;

  @override
  ScanShotRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanShotRecord(
      file: fields[0] as String,
      sha256: fields[1] as String,
      capturedAt: fields[2] as DateTime,
      ring: fields[3] as int,
      sector: fields[4] as int,
      uploaded: fields[5] == null ? false : fields[5] as bool,
      serverSequence: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ScanShotRecord obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.file)
      ..writeByte(1)
      ..write(obj.sha256)
      ..writeByte(2)
      ..write(obj.capturedAt)
      ..writeByte(3)
      ..write(obj.ring)
      ..writeByte(4)
      ..write(obj.sector)
      ..writeByte(5)
      ..write(obj.uploaded)
      ..writeByte(6)
      ..write(obj.serverSequence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanShotRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ObjectScanRecordAdapter extends TypeAdapter<ObjectScanRecord> {
  @override
  final int typeId = 15;

  @override
  ObjectScanRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ObjectScanRecord(
      wallId: fields[0] as String,
      floorId: fields[1] as String,
      siteId: fields[2] as String,
      clientUuid: fields[3] as String,
      shots: (fields[4] as List).cast<ScanShotRecord>(),
      createdAt: fields[5] as DateTime,
      isFinished: fields[6] == null ? false : fields[6] as bool,
      fullCircle: fields[7] == null ? true : fields[7] as bool,
      isConfirmed: fields[8] == null ? false : fields[8] as bool,
      serverScanId: fields[9] as int?,
      serverStatus: fields[10] as String?,
      serverReasons: fields[11] == null
          ? []
          : (fields[11] as List).cast<String>(),
      serverGaps: fields[12] == null ? [] : (fields[12] as List).cast<double>(),
      serverUnplaced: fields[15] == null
          ? []
          : (fields[15] as List).cast<int>(),
      serverFailureReason: fields[13] as String?,
      serverRunProgress: fields[14] == null ? 0.0 : fields[14] as double,
      previewId: fields[16] as int?,
      previewStatus: fields[17] as String?,
      previewProgress: fields[18] == null ? 0.0 : fields[18] as double,
      previewUnseenFraction: fields[19] as double?,
      previewMissingCells: fields[20] == null
          ? []
          : (fields[20] as List).cast<int>(),
      previewModelFile: fields[21] as String?,
      cellsToRetake: fields[22] == null ? [] : (fields[22] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, ObjectScanRecord obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.wallId)
      ..writeByte(1)
      ..write(obj.floorId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.clientUuid)
      ..writeByte(4)
      ..write(obj.shots)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.isFinished)
      ..writeByte(7)
      ..write(obj.fullCircle)
      ..writeByte(8)
      ..write(obj.isConfirmed)
      ..writeByte(9)
      ..write(obj.serverScanId)
      ..writeByte(10)
      ..write(obj.serverStatus)
      ..writeByte(11)
      ..write(obj.serverReasons)
      ..writeByte(12)
      ..write(obj.serverGaps)
      ..writeByte(13)
      ..write(obj.serverFailureReason)
      ..writeByte(14)
      ..write(obj.serverRunProgress)
      ..writeByte(15)
      ..write(obj.serverUnplaced)
      ..writeByte(16)
      ..write(obj.previewId)
      ..writeByte(17)
      ..write(obj.previewStatus)
      ..writeByte(18)
      ..write(obj.previewProgress)
      ..writeByte(19)
      ..write(obj.previewUnseenFraction)
      ..writeByte(20)
      ..write(obj.previewMissingCells)
      ..writeByte(21)
      ..write(obj.previewModelFile)
      ..writeByte(22)
      ..write(obj.cellsToRetake);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectScanRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
