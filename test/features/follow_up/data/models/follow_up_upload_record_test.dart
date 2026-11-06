import 'dart:io';

import 'package:digitization_platform/core/data/models/hive_type_ids.dart';
import 'package:digitization_platform/features/follow_up/data/models/follow_up_upload_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Writes a record the way the app did before it knew about widths: 21 fields.
class _BeforeWidthsAdapter extends TypeAdapter<FollowUpUploadRecord> {
  @override
  final int typeId = HiveTypeIds.followUpUploadRecord;

  @override
  FollowUpUploadRecord read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, FollowUpUploadRecord obj) {
    final fields = <int, Object?>{
      0: obj.token,
      1: obj.kind,
      2: obj.siteId,
      3: obj.packageId,
      4: obj.itemKey,
      5: obj.label,
      6: obj.filePath,
      7: obj.sha256,
      8: obj.capturedAt,
      9: obj.videoMatchJson,
      10: obj.warningConfirmed,
      11: obj.suggestedCornersJson,
      12: obj.status,
      13: obj.attempts,
      14: obj.lastError,
      15: obj.serverStatus,
      16: obj.grade,
      17: obj.baselineGrade,
      18: obj.reasons,
      19: obj.rejectReason,
      20: obj.createdAt,
    };
    writer.writeByte(fields.length);
    fields.forEach((index, value) {
      writer.writeByte(index);
      writer.write(value);
    });
  }
}

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('follow_up_record_');
    Hive.init(folder.path);
  });

  tearDown(() async {
    await Hive.close();
    folder.deleteSync(recursive: true);
  });

  FollowUpUploadRecord record({double? width, String? source}) => FollowUpUploadRecord(
    token: 'a',
    kind: FollowUpUploadRecord.kindTarget,
    siteId: '1',
    packageId: 1,
    itemKey: 'abcdefghij',
    label: 'Wall-1',
    filePath: 'x.jpg',
    sha256: 'abc',
    capturedAt: DateTime(2026),
    createdAt: DateTime(2026),
    physicalWidthM: width,
    widthSource: source,
  );

  test('a width survives being stored', () async {
    Hive.registerAdapter(FollowUpUploadRecordAdapter(), override: true);
    final box = await Hive.openBox<FollowUpUploadRecord>('stored');

    await box.put('a', record(width: 1.42, source: 'ar'));
    await box.close();

    final reopened = await Hive.openBox<FollowUpUploadRecord>('stored');
    expect(reopened.get('a')!.physicalWidthM, 1.42);
    expect(reopened.get('a')!.widthSource, 'ar');
  });

  test('a grid survives being stored, with which of its photographs went', () async {
    Hive.registerAdapter(FollowUpUploadRecordAdapter(), override: true);
    final box = await Hive.openBox<FollowUpUploadRecord>('grid');

    await box.put(
      'a',
      FollowUpUploadRecord(
        token: 'a',
        kind: FollowUpUploadRecord.kindAnnotationGrid,
        siteId: '1',
        packageId: 1,
        itemKey: '41',
        label: 'W-1',
        filePath: '',
        sha256: '',
        capturedAt: DateTime(2026),
        createdAt: DateTime(2026),
        rows: 1,
        cols: 2,
        failedCellsJson: '[{"row":0,"col":1,"reason":"no overlap"}]',
      )..tiles = const [
        GridTile(row: 0, col: 0, path: 'a.jpg', sha256: 'x', sent: true),
        GridTile(row: 0, col: 1, path: 'b.jpg', sha256: 'y'),
      ],
    );
    await box.close();

    final read = (await Hive.openBox<FollowUpUploadRecord>('grid')).get('a')!;
    expect(read.rows, 1);
    expect(read.cols, 2);
    expect(read.tiles.map((tile) => tile.sent), [true, false]);
    expect(read.tiles.last.path, 'b.jpg');
    expect(read.failedCells.single, (row: 0, col: 1));
    expect(read.family, FollowUpUploadRecord.kindAnnotation);
  });

  test('a record from before grids has none of it', () async {
    Hive.registerAdapter(_BeforeWidthsAdapter(), override: true);
    final old = await Hive.openBox<FollowUpUploadRecord>('old-grid');
    await old.put('a', record());
    await old.close();

    Hive.registerAdapter(FollowUpUploadRecordAdapter(), override: true);
    final read = (await Hive.openBox<FollowUpUploadRecord>('old-grid')).get('a')!;

    expect(read.isGrid, isFalse);
    expect(read.tiles, isEmpty);
    expect(read.failedCells, isEmpty);
  });

  test('a record queued before widths existed still opens, with none', () async {
    Hive.registerAdapter(_BeforeWidthsAdapter(), override: true);
    final old = await Hive.openBox<FollowUpUploadRecord>('old');
    await old.put('a', record());
    await old.close();

    Hive.registerAdapter(FollowUpUploadRecordAdapter(), override: true);
    final reopened = await Hive.openBox<FollowUpUploadRecord>('old');

    final read = reopened.get('a')!;
    expect(read.token, 'a');
    expect(read.createdAt, DateTime(2026));
    expect(read.physicalWidthM, isNull);
    expect(read.widthSource, isNull);
  });
}
