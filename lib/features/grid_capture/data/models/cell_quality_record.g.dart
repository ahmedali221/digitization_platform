// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cell_quality_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NeighbourQualityRecordAdapter
    extends TypeAdapter<NeighbourQualityRecord> {
  @override
  final int typeId = 10;

  @override
  NeighbourQualityRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NeighbourQualityRecord(
      direction: fields[0] as String,
      neighbourCellIndex: fields[1] as int,
      goodMatches: fields[2] as int,
      ransacInliers: fields[3] as int,
      inlierRatio: fields[4] as double,
      dx: fields[5] as double,
      dy: fields[6] as double,
      scale: fields[7] as double,
      directionOk: fields[8] as bool,
      scaleOk: fields[9] as bool,
      neighbourScore: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, NeighbourQualityRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.direction)
      ..writeByte(1)
      ..write(obj.neighbourCellIndex)
      ..writeByte(2)
      ..write(obj.goodMatches)
      ..writeByte(3)
      ..write(obj.ransacInliers)
      ..writeByte(4)
      ..write(obj.inlierRatio)
      ..writeByte(5)
      ..write(obj.dx)
      ..writeByte(6)
      ..write(obj.dy)
      ..writeByte(7)
      ..write(obj.scale)
      ..writeByte(8)
      ..write(obj.directionOk)
      ..writeByte(9)
      ..write(obj.scaleOk)
      ..writeByte(10)
      ..write(obj.neighbourScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeighbourQualityRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShotQualityScoreRecordAdapter
    extends TypeAdapter<ShotQualityScoreRecord> {
  @override
  final int typeId = 11;

  @override
  ShotQualityScoreRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShotQualityScoreRecord(
      imagePath: fields[0] as String,
      cellScore: fields[1] as double,
      status: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ShotQualityScoreRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.imagePath)
      ..writeByte(1)
      ..write(obj.cellScore)
      ..writeByte(2)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotQualityScoreRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CellQualityRecordAdapter extends TypeAdapter<CellQualityRecord> {
  @override
  final int typeId = 9;

  @override
  CellQualityRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CellQualityRecord(
      keypointCount: fields[0] as int,
      keypointDensity: fields[1] as double,
      spatialDistribution: fields[2] as double,
      edgeLeft: fields[3] as int,
      edgeRight: fields[4] as int,
      edgeTop: fields[5] as int,
      edgeBottom: fields[6] as int,
      relevantEdgeDensity: fields[7] as double,
      sharpness: fields[8] as double,
      contrast: fields[9] as double,
      imageScore: fields[10] as double,
      neighbours: (fields[11] as List).cast<NeighbourQualityRecord>(),
      cellScore: fields[12] as double,
      status: fields[13] as String,
      failureReason: fields[14] as String?,
      computedAt: fields[15] as DateTime,
      imagePath: fields[16] as String?,
      allShotScores: fields[17] == null
          ? []
          : (fields[17] as List).cast<ShotQualityScoreRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, CellQualityRecord obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.keypointCount)
      ..writeByte(1)
      ..write(obj.keypointDensity)
      ..writeByte(2)
      ..write(obj.spatialDistribution)
      ..writeByte(3)
      ..write(obj.edgeLeft)
      ..writeByte(4)
      ..write(obj.edgeRight)
      ..writeByte(5)
      ..write(obj.edgeTop)
      ..writeByte(6)
      ..write(obj.edgeBottom)
      ..writeByte(7)
      ..write(obj.relevantEdgeDensity)
      ..writeByte(8)
      ..write(obj.sharpness)
      ..writeByte(9)
      ..write(obj.contrast)
      ..writeByte(10)
      ..write(obj.imageScore)
      ..writeByte(11)
      ..write(obj.neighbours)
      ..writeByte(12)
      ..write(obj.cellScore)
      ..writeByte(13)
      ..write(obj.status)
      ..writeByte(14)
      ..write(obj.failureReason)
      ..writeByte(15)
      ..write(obj.computedAt)
      ..writeByte(16)
      ..write(obj.imagePath)
      ..writeByte(17)
      ..write(obj.allShotScores);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellQualityRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
