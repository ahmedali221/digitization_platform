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
}
