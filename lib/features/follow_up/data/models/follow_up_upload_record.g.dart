// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_up_upload_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FollowUpUploadRecordAdapter extends TypeAdapter<FollowUpUploadRecord> {
  @override
  final int typeId = 12;

  @override
  FollowUpUploadRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FollowUpUploadRecord(
      token: fields[0] as String,
      kind: fields[1] as String,
      siteId: fields[2] as String,
      packageId: fields[3] as int,
      itemKey: fields[4] as String,
      label: fields[5] as String,
      filePath: fields[6] as String,
      sha256: fields[7] as String,
      capturedAt: fields[8] as DateTime,
      videoMatchJson: fields[9] as String?,
      warningConfirmed: fields[10] as bool,
      suggestedCornersJson: fields[11] as String?,
      status: fields[12] as String,
      attempts: fields[13] as int,
      lastError: fields[14] as String?,
      serverStatus: fields[15] as String?,
      grade: fields[16] as String?,
      baselineGrade: fields[17] as String?,
      reasons: (fields[18] as List).cast<String>(),
      rejectReason: fields[19] as String?,
      createdAt: fields[20] as DateTime,
      physicalWidthM: fields[21] as double?,
      widthSource: fields[22] as String?,
      previewPath: fields[23] as String?,
      rows: fields[24] as int?,
      cols: fields[25] as int?,
      tilesJson: fields[26] as String?,
      failedCellsJson: fields[27] as String?,
      description: fields[28] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FollowUpUploadRecord obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.token)
      ..writeByte(1)
      ..write(obj.kind)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.packageId)
      ..writeByte(4)
      ..write(obj.itemKey)
      ..writeByte(5)
      ..write(obj.label)
      ..writeByte(6)
      ..write(obj.filePath)
      ..writeByte(7)
      ..write(obj.sha256)
      ..writeByte(8)
      ..write(obj.capturedAt)
      ..writeByte(9)
      ..write(obj.videoMatchJson)
      ..writeByte(10)
      ..write(obj.warningConfirmed)
      ..writeByte(11)
      ..write(obj.suggestedCornersJson)
      ..writeByte(12)
      ..write(obj.status)
      ..writeByte(13)
      ..write(obj.attempts)
      ..writeByte(14)
      ..write(obj.lastError)
      ..writeByte(15)
      ..write(obj.serverStatus)
      ..writeByte(16)
      ..write(obj.grade)
      ..writeByte(17)
      ..write(obj.baselineGrade)
      ..writeByte(18)
      ..write(obj.reasons)
      ..writeByte(19)
      ..write(obj.rejectReason)
      ..writeByte(20)
      ..write(obj.createdAt)
      ..writeByte(21)
      ..write(obj.physicalWidthM)
      ..writeByte(22)
      ..write(obj.widthSource)
      ..writeByte(23)
      ..write(obj.previewPath)
      ..writeByte(24)
      ..write(obj.rows)
      ..writeByte(25)
      ..write(obj.cols)
      ..writeByte(26)
      ..write(obj.tilesJson)
      ..writeByte(27)
      ..write(obj.failedCellsJson)
      ..writeByte(28)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUpUploadRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
