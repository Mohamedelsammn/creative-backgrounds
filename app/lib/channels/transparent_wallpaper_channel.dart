import 'package:flutter/services.dart';

import '../features/transparent_wallpaper/data/models/compatibility_report_model.dart';
import '../features/transparent_wallpaper/data/models/tw_permissions_model.dart';
import '../features/transparent_wallpaper/data/models/tw_status_model.dart';
import '../features/transparent_wallpaper/domain/entities/compatibility_report.dart';
import '../features/transparent_wallpaper/domain/entities/tw_permissions.dart';
import '../features/transparent_wallpaper/domain/entities/tw_status.dart';

/// Flutter side of the transparent (live rear-camera) wallpaper channel.
///
/// The native side owns all state; Flutter only issues commands and reads back
/// results. This wrapper grows phase-by-phase — Phase 2 exposes only the
/// compatibility check.
class TransparentWallpaperChannel {
  static const MethodChannel _channel =
      MethodChannel('com.creative.backgrounds/transparent');
  static const EventChannel _events =
      EventChannel('com.creative.backgrounds/transparent_events');

  /// Asks the native `CompatibilityChecker` whether this device can run the
  /// feature. Never guessed on the Flutter side.
  Future<CompatibilityReport> checkCompatibility() async {
    final raw = await _channel
        .invokeMapMethod<dynamic, dynamic>('checkCompatibility');
    return CompatibilityReportModel.fromMap(raw ?? const {});
  }

  /// Current permission state without prompting the user.
  Future<TwPermissions> getPermissionStatus() async {
    final raw = await _channel
        .invokeMapMethod<dynamic, dynamic>('getPermissionStatus');
    return TwPermissionsModel.fromMap(raw ?? const {});
  }

  /// Prompts for any missing permissions; resolves with the resulting state.
  Future<TwPermissions> requestPermissions() async {
    final raw = await _channel
        .invokeMapMethod<dynamic, dynamic>('requestPermissions');
    return TwPermissionsModel.fromMap(raw ?? const {});
  }

  /// Opens this app's system settings page (for permanently-denied recovery).
  Future<bool> openAppSettings() async {
    final ok = await _channel.invokeMethod<bool>('openAppSettings');
    return ok ?? false;
  }

  /// Opens battery-optimization settings (OEM background-kill mitigation).
  Future<bool> openBatterySettings() async {
    final ok = await _channel.invokeMethod<bool>('openBatterySettings');
    return ok ?? false;
  }

  /// Begins the apply flow: snapshots the current wallpaper, starts the
  /// foreground camera service, and opens the system live-wallpaper picker.
  Future<void> start() => _channel.invokeMethod<void>('start');

  /// Disables the feature, releases the camera service, restores the wallpaper.
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  /// Pauses rendering (state only; the engine stops the camera when hidden).
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  /// Resumes from a paused state.
  Future<void> resume() => _channel.invokeMethod<void>('resume');

  /// Restores the saved wallpaper without changing the enabled flag.
  Future<void> restorePreviousWallpaper() =>
      _channel.invokeMethod<void>('restorePreviousWallpaper');

  /// One-shot current native state (used on resume / cold start).
  Future<TwRuntimeState> status() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>('status');
    return TwStatusModel.fromMap(raw ?? const {});
  }

  /// Reads the persisted target FPS (default 24).
  Future<int> getFps() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>('getSettings');
    return (raw?['fps'] as num?)?.toInt() ?? 24;
  }

  /// Persists the target FPS (applied natively on the next camera bind).
  Future<void> updateFps(int fps) =>
      _channel.invokeMethod<void>('updateSettings', {'fps': fps});

  /// Live stream of native state changes (emits the current state on listen).
  Stream<TwRuntimeState> statusStream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) return TwStatusModel.fromMap(event);
      return TwRuntimeState.idle;
    });
  }
}
