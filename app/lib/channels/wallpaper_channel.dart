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
      MethodChannel('com.backgrounds.trend4k/wallpaper');

  Future<bool> applyWallpaper({
    required String imagePath,
    required ApplyDestination destination,
    String? clockConfigJson,
    bool depthEnabled = false,
    String? maskPath,
    String? depthConfigJson,
    String? widgetsJson,
    String? dateWidgetJson,
  }) async {
    final isLive = clockConfigJson != null || depthEnabled;
    final result = await _channel.invokeMethod<bool>('applyWallpaper', {
      'imagePath': imagePath,
      'destination': destination.name,
      'clockConfig': clockConfigJson,
      // Serialized `studio.widgets`, drawn over the clock by the native
      // renderer. Null clears any previously applied widgets, so a re-apply
      // without one does not leave a stale ring drawn on top.
      'widgets': widgetsJson,
      // The independently-positioned date element.
      'dateWidget': dateWidgetJson,
      'depthEnabled': depthEnabled,
      'maskPath': maskPath,
      // Backend-authored foreground transform, consumed by the native
      // compositor. Null means "identity transform".
      'depthConfig': depthConfigJson,
      'isLive': isLive,
    });
    return result ?? false;
  }

  /// Applies a looping video wallpaper.
  ///
  /// [videoPath] and [posterPath] are local files - the video pipeline stays
  /// entirely native, so Flutter never decodes or processes a frame. Returns
  /// false when the device has no live-wallpaper picker.
  ///
  /// [clockConfigJson] carries the same serialized `ClockConfigEntity` the
  /// static/depth path sends via [applyWallpaper] - native composites it over
  /// the decoded video frames. Null clears any previously applied clock, so a
  /// re-apply without a clock does not leave a stale one drawn on top.
  Future<bool> applyVideoWallpaper({
    required String videoPath,
    String? posterPath,
    String? clockConfigJson,
    String? widgetsJson,
    String? dateWidgetJson,
  }) async {
    final result = await _channel.invokeMethod<bool>('applyVideoWallpaper', {
      'videoPath': videoPath,
      'posterPath': posterPath,
      'clockConfig': clockConfigJson,
      'widgets': widgetsJson,
      'dateWidget': dateWidgetJson,
    });
    return result ?? false;
  }

  Future<bool> requestWallpaperPermission() async {
    final result =
        await _channel.invokeMethod<bool>('requestWallpaperPermission');
    return result ?? false;
  }

  /// Reads and clears the outcome of the last system live-wallpaper picker
  /// launch ([applyWallpaper]'s live branch, or [applyVideoWallpaper]).
  ///
  /// `ACTION_CHANGE_LIVE_WALLPAPER` gives no result callback, so this is the
  /// only way the app can ever learn what happened after the picker closed -
  /// native reconciles it against `WallpaperManager` on `Activity.onResume`
  /// and this consumes that one-shot result. Call once per app resume.
  Future<LiveWallpaperApplyOutcome> consumePendingApplyOutcome() async {
    final result =
        await _channel.invokeMethod<String>('consumePendingApplyOutcome');
    return switch (result) {
      'applied' => LiveWallpaperApplyOutcome.applied,
      'cancelled' => LiveWallpaperApplyOutcome.cancelled,
      _ => LiveWallpaperApplyOutcome.none,
    };
  }
}

/// Outcome of a system live-wallpaper picker launch, learned on the next
/// app resume since Android gives no direct result callback for it.
enum LiveWallpaperApplyOutcome {
  /// Nothing was pending, or resolving.
  none,

  /// The system now reports our live wallpaper service as active.
  applied,

  /// A picker was launched but our service is not active - the user backed
  /// out, cancelled, or the picker failed.
  cancelled,
}
