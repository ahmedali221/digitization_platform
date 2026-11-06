import 'package:flutter/services.dart';

enum ArMeasureStatus { measured, cancelled, unavailable }

class ArMeasureResult {
  const ArMeasureResult(this.status, {this.meters, this.reason});

  final ArMeasureStatus status;

  /// Set when [status] is [ArMeasureStatus.measured].
  final double? meters;

  /// Why AR can't be used, in words for the operator, when the platform knows.
  final String? reason;
}

/// Opens the native screen that measures a target's width with the camera:
/// ARCore on Android (`ArMeasureActivity.kt`), ARKit on iPhone
/// (`ArMeasureViewController.swift`). Both report the horizontal distance
/// between two points in metres.
class ArMeasureChannel {
  ArMeasureChannel._();

  static const _channel = MethodChannel('nilelens/ar_measure');

  /// False on a phone that can't do AR, so the operator goes straight to typing.
  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<ArMeasureResult> measure() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('measure');
      final meters = (result?['meters'] as num?)?.toDouble();
      return switch (result?['status']) {
        'measured' when meters != null => ArMeasureResult(ArMeasureStatus.measured, meters: meters),
        'cancelled' => const ArMeasureResult(ArMeasureStatus.cancelled),
        _ => ArMeasureResult(ArMeasureStatus.unavailable, reason: result?['reason'] as String?),
      };
    } on MissingPluginException {
      return const ArMeasureResult(ArMeasureStatus.unavailable);
    } on PlatformException catch (e) {
      return ArMeasureResult(ArMeasureStatus.unavailable, reason: e.message);
    }
  }
}
