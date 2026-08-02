import 'dart:io';

import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../../../../core/storage/directory_manager.dart';
import '../../../../core/storage/hive_boxes.dart';
import '../models/unassigned_capture_record.dart';

/// Hive CRUD + shot file I/O for local-id (unassigned) wall captures.
/// Mirrors `GridCaptureLocalDataSource`/`CaptureSessionLocalDataSource`'s
/// split — [saveShot]/[deleteShot] only touch disk, [recordShot]/
/// [removeShot] only touch the Hive record — so the cubit layer saves a
/// shot first (mirroring `CaptureSessionCubit.takePhoto`), then hands the
/// resulting plain `filePath`/`sha256` to the repository, matching how
/// `GridCaptureRepository.capturePhoto` is called. Directory conventions
/// (`sessions/{localId}` + `backup/{localId}`, immediate backup copy, atomic
/// writes) are unchanged from grid capture — just flat (no row/col), since
/// unassigned captures aren't gridded until a real wall id resolves
/// (FLUTTER_MOBILE_PLAN.md §5).
class UnassignedCaptureLocalDataSource {
  UnassignedCaptureLocalDataSource({DirectoryManager? directoryManager})
    : _directoryManager = directoryManager ?? DirectoryManager();

  final DirectoryManager _directoryManager;

  Box<UnassignedCaptureRecord> get _box =>
      Hive.box<UnassignedCaptureRecord>(HiveBoxes.unassignedCaptures);

  UnassignedCaptureRecord? get(String localId) => _box.get(localId);

  List<UnassignedCaptureRecord> all() => _box.values.toList();

  Stream<List<UnassignedCaptureRecord>> watchAll() async* {
    yield all();
    yield* _box.watch().map((_) => all());
  }

  Future<void> put(UnassignedCaptureRecord record) =>
      _box.put(record.localId, record);

  Future<UnassignedCaptureRecord> ensure({
    required String localId,
    required String siteId,
    required String floorId,
  }) async {
    final existing = _box.get(localId);
    if (existing != null) return existing;
    final record = UnassignedCaptureRecord(
      localId: localId,
      siteId: siteId,
      floorId: floorId,
      createdAt: DateTime.now(),
    );
    await _box.put(localId, record);
    return record;
  }

  Future<({String path, String sha256})> saveShot({
    required String localId,
    required int shotNumber,
    required XFile capturedFile,
  }) async {
    final sessionDir = await _directoryManager.sessionDir(localId);
    final fileName = 'S$shotNumber.jpg';
    final targetPath = p.join(sessionDir.path, fileName);
    await capturedFile.saveTo(targetPath);

    final backupDir = await _directoryManager.backupDir(localId);
    await File(targetPath).copy(p.join(backupDir.path, fileName));

    final checksum = await _sha256Of(targetPath);
    return (path: targetPath, sha256: checksum);
  }

  Future<void> deleteShot({
    required String localId,
    required String filePath,
  }) async {
    final sessionFile =
        await _directoryManager.resolveExistingFile(filePath) ??
        File(filePath);
    if (await sessionFile.exists()) await sessionFile.delete();
    final backupDir = await _directoryManager.backupDir(localId);
    final backupFile = File(p.join(backupDir.path, p.basename(filePath)));
    if (await backupFile.exists()) await backupFile.delete();
  }

  /// Re-anchors any stale absolute paths in [localId]'s shots against the
  /// current documents root (see `DirectoryManager.resolveExistingFile`)
  /// and persists the correction, so a given stale path only ever needs
  /// resolving once. Paths that can't be found under either root are left
  /// as-is — the UI falls back to a placeholder for those.
  Future<UnassignedCaptureRecord?> healPaths(String localId) async {
    final record = _box.get(localId);
    if (record == null) return null;

    var changed = false;
    final healedShots = <String>[];
    for (final path in record.shots) {
      final resolved = await _directoryManager.resolveExistingFile(path);
      final healedPath = resolved?.path ?? path;
      if (healedPath != path) changed = true;
      healedShots.add(healedPath);
    }
    if (changed) {
      record.shots = healedShots;
      await record.save();
    }
    return record;
  }

  Future<UnassignedCaptureRecord> recordShot({
    required String localId,
    required String filePath,
    required String sha256,
  }) async {
    final record = _box.get(localId);
    if (record == null) {
      throw StateError('No capture record for $localId — call ensure() first.');
    }
    record.shots = [...record.shots, filePath];
    record.checksums = [...record.checksums, sha256];
    await record.save();
    return record;
  }

  Future<UnassignedCaptureRecord?> removeShot({
    required String localId,
    required String filePath,
  }) async {
    final record = _box.get(localId);
    if (record == null) return null;
    final index = record.shots.indexOf(filePath);
    if (index == -1) return record;

    final shots = List<String>.of(record.shots)..removeAt(index);
    final checksums = List<String>.of(record.checksums)..removeAt(index);
    record.shots = shots;
    record.checksums = checksums;
    await record.save();
    return record;
  }

  Future<String> _sha256Of(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
