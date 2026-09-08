import 'dart:io';

import 'package:flutter/services.dart';

/// Copies a file the app already saved privately into the device's public
/// Downloads folder via a native `MediaStore.Downloads` write, so it's
/// browsable from a file manager without going through the share sheet.
///
/// Android only, deliberately: exposing the equivalent (the app's private
/// sandbox) on iOS would also make the in-progress capture folders
/// (`sessions/`, `backup/` — see `DirectoryManager`'s Invariant 1) editable
/// or deletable from the Files app, risking active capture data. iOS keeps
/// the share-sheet's "Save to Files" as its one-tap equivalent instead.
///
/// Best-effort: never throws. A failure here (permission, platform quirk)
/// must never fail the backup itself — the zip already exists in app
/// storage and can still be shared.
class PublicDownloadsChannel {
  PublicDownloadsChannel._();

  static const _channel = MethodChannel('nilelens/public_downloads');

  static Future<bool> exportToDownloads(File file, String displayName) async {
    if (!Platform.isAndroid) return false;
    try {
      final savedUri = await _channel.invokeMethod<String>(
        'exportToDownloads',
        {'sourcePath': file.path, 'displayName': displayName},
      );
      return savedUri != null;
    } catch (_) {
      return false;
    }
  }
}
