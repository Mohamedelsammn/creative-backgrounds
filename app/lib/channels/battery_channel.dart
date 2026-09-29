import 'package:flutter/services.dart';

/// Reads the device's current battery level for the `batteryRing` studio
/// widget.
///
/// Backed by Android's `BatteryManager`, which requires **no permission** -
/// see `BatteryChannel.kt`. Nothing here requests location, network or any
/// dangerous permission.
class BatteryChannel {
  const BatteryChannel._();

  static const MethodChannel _channel = MethodChannel(
    'com.backgrounds.trend4k/battery',
  );

  /// The battery level as 0..100, or null when it cannot be read (an
  /// unsupported device, or any platform failure).
  ///
  /// Never throws: a design that includes a battery ring must still render
  /// when the level is unavailable, showing no level rather than an error.
  static Future<int?> level() async {
    try {
      final value = await _channel.invokeMethod<int>('level');
      if (value == null || value < 0 || value > 100) return null;
      return value;
    } catch (_) {
      return null;
    }
  }
}
