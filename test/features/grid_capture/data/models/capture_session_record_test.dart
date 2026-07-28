import 'package:digitization_platform/features/grid_capture/data/models/capture_session_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CapturePhotoRecord photo(String path, int shot) => CapturePhotoRecord(
    file: path,
    sha256: 'checksum-$shot',
    shot: shot,
    capturedAt: DateTime(2026, 7, 28),
  );

  CaptureSessionRecord session() => CaptureSessionRecord(
    sessionId: 'wall-1',
    wallId: 'wall-1',
    floorId: 'floor-1',
    siteId: 'site-1',
    gridRows: 1,
    gridCols: 2,
    cells: [
      CaptureCellRecord(
        row: 0,
        col: 0,
        photos: [photo('R1C1_S1.jpg', 1), photo('R1C1_S2.jpg', 2)],
      ),
      CaptureCellRecord(row: 0, col: 1, photos: [photo('R1C2_S1.jpg', 1)]),
    ],
    state: 'completed',
    createdAt: DateTime(2026, 7, 28),
  );

  test('removes only the selected photo from its grid cell', () {
    final record = session();

    final removed = record.removePhotoAt(0, 0, 'R1C1_S1.jpg');

    expect(removed, isTrue);
    expect(record.cellAt(0, 0).photos.map((photo) => photo.file), [
      'R1C1_S2.jpg',
    ]);
    expect(record.cellAt(0, 1).photos.single.file, 'R1C2_S1.jpg');
    expect(record.isComplete, isTrue);
  });

  test('reports a missing photo without changing the session', () {
    final record = session();

    final removed = record.removePhotoAt(0, 0, 'missing.jpg');

    expect(removed, isFalse);
    expect(record.cellAt(0, 0).photos, hasLength(2));
    expect(record.filledCellCount, 2);
  });
}
