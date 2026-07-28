import 'package:flutter/services.dart';

/// Where a wallpaper is applied.
enum ApplyDestination { homeScreen, lockScreen, both }

/// Flutter side of the wallpaper platform channel.
///
/// Files are downloaded to disk on the Flutter side and passed as paths — never
/// raw bytes — to keep channel payloads small and avoid native networking.
///
/// A wallpaper with a clock or depth is applied as a **live wallpaper** (so the
/// clock ticks) via the system picker; a plain image is applied silently with
/// `WallpaperManager.setBitmap`.
class WallpaperChannel {
  static const MethodChannel _channel =
      MethodChannel('com.creative.backgrounds/wallpaper');

  Future<bool> applyWallpaper({
    required String imagePath,
    required ApplyDestination destination,
    String? clockConfigJson,
    bool depthEnabled = false,
    String? maskPath,
  }) async {
    final isLive = clockConfigJson != null || depthEnabled;
    final result = await _channel.invokeMethod<bool>('applyWallpaper', {
      'imagePath': imagePath,
      'destination': destination.name,
      'clockConfig': clockConfigJson,
      'depthEnabled': depthEnabled,
      'maskPath': maskPath,
      'isLive': isLive,
    });
    return result ?? false;
  }

  Future<bool> requestWallpaperPermission() async {
    final result =
        await _channel.invokeMethod<bool>('requestWallpaperPermission');
    return result ?? false;
  }
}
