import 'package:hive/hive.dart';

import '../../../../core/storage/hive_boxes.dart';

/// Persists the operator's last-picked camera capture preferences
/// (auto-advance, flash mode) across the whole app, not just one wall — a
/// fresh [CaptureSessionCubit]/camera screen is created every time the
/// operator opens a different wall or room, so without this every move
/// between walls would silently reset back to the defaults instead of
/// carrying the operator's choice forward.
class CameraPreferencesLocalDataSource {
  static const _autoAdvanceKey = 'auto_advance';
  static const _flashModeKey = 'flash_mode';

  Box get _box => Hive.box(HiveBoxes.settings);

  bool getAutoAdvance() => (_box.get(_autoAdvanceKey) as bool?) ?? false;

  Future<void> setAutoAdvance(bool value) => _box.put(_autoAdvanceKey, value);

  /// The raw `FlashMode.name` string ('off'/'auto'/'torch'/'always') — kept
  /// as a plain string rather than the `camera` package's enum so this data
  /// layer doesn't need to depend on it; the camera page maps it back.
  String? getFlashModeName() => _box.get(_flashModeKey) as String?;

  Future<void> setFlashModeName(String name) => _box.put(_flashModeKey, name);
}
