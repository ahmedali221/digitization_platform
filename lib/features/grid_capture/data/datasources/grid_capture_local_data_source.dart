import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves a just-captured shot to local storage using the
/// `R{row}C{col}_S{shot}.jpg` naming convention from
/// ../../../../../Digitization-Platform/FLUTTER_MOBILE_PLAN.md Phase 3, one
/// directory per wall capture session. Pure file I/O — no grid/wall state,
/// which stays with [GridCaptureRepository].
class GridCaptureLocalDataSource {
  Future<String> saveShot({
    required String floorId,
    required String wallId,
    required int row,
    required int col,
    required int shotNumber,
    required XFile capturedFile,
  }) async {
    final sessionDir = await _sessionDirectory(floorId, wallId);
    final targetPath = p.join(
      sessionDir.path,
      'R${row}C${col}_S$shotNumber.jpg',
    );
    await capturedFile.saveTo(targetPath);
    return targetPath;
  }

  Future<Directory> _sessionDirectory(String floorId, String wallId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory(
      p.join(docsDir.path, 'captures', floorId, wallId),
    );
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }
}
