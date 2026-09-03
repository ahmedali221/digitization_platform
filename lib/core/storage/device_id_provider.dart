import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'hive_boxes.dart';

/// Generates a stable per-install device UUID once, persists it in the
/// `device` box, and returns the same value on every subsequent call.
/// Required on every sync payload (FLUTTER_MOBILE_PLAN.md §3/§8).
class DeviceIdProvider {
  DeviceIdProvider({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const _key = 'device_id';

  final Uuid _uuid;

  Future<String> getOrCreateDeviceId() async {
    final box = Hive.box(HiveBoxes.device);
    final existing = box.get(_key) as String?;
    if (existing != null) return existing;

    final generated = _uuid.v4();
    await box.put(_key, generated);
    return generated;
  }

  /// Whether this install has ever generated a device id, without creating
  /// one. The `device` box lives in the same sandboxed Documents directory
  /// as every other Hive box, so it comes back empty whenever iOS performs a
  /// true reinstall (as opposed to an in-place update) — unlike the Keychain
  /// entry backing the auth token, which survives a reinstall. Used by
  /// AuthRepositoryImpl to detect a stale token surviving a wiped sandbox.
  bool hasExistingDeviceId() => Hive.box(HiveBoxes.device).containsKey(_key);
}
