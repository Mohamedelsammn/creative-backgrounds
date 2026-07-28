import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Flutter side of the clock platform channel. Writes the serialized
/// [ClockConfig] JSON to native SharedPreferences so `ClockRenderer.kt` and the
/// live wallpaper can read it. Fails soft if the native side isn't available.
class ClockChannel {
  static const MethodChannel _channel =
      MethodChannel('com.creative.backgrounds/clock');

  Future<void> saveClockConfig(Map<String, dynamic> configJson) async {
    try {
      await _channel.invokeMethod<void>('saveClockConfig', jsonEncode(configJson));
    } on MissingPluginException {
      // Native handler not registered (e.g. during unit tests) — no-op.
    } on PlatformException catch (e) {
      developer.log('saveClockConfig failed: ${e.message}', name: 'ClockChannel');
    }
  }

  Future<void> clearClockConfig() async {
    try {
      await _channel.invokeMethod<void>('clearClockConfig');
    } on MissingPluginException {
      // no-op
    } on PlatformException catch (e) {
      developer.log('clearClockConfig failed: ${e.message}',
          name: 'ClockChannel');
    }
  }
}
