/// The three kinds of wallpaper the catalog can serve, plus an escape hatch.
///
/// The wire values come from the public API's `type` field (lower-case:
/// `standard` / `depth` / `video`; the admin API uses the upper-case forms).
/// A value we do not recognise maps to [unknown] rather than throwing, so a
/// future content type added server-side degrades to "visible but not
/// applyable" instead of breaking every list in the app.
enum WallpaperType {
  /// A single flat image. Wire: `standard`.
  normal,

  /// Background + cut-out foreground + an authored clock configuration, so the
  /// clock can sit *behind* the subject. Wire: `depth`.
  depth,

  /// A looping video wallpaper. Wire: `video`.
  ///
  /// Unrelated to Android's `LiveWallpaperService`, which is the *rendering
  /// mechanism* this app already uses for clock/depth wallpapers.
  live,

  /// A type this build does not understand.
  unknown;

  /// Parses the API's `type` field. Case-insensitive, null-safe.
  static WallpaperType fromWire(Object? raw) {
    if (raw is! String) return WallpaperType.unknown;
    return switch (raw.trim().toLowerCase()) {
      'standard' || 'normal' => WallpaperType.normal,
      'depth' => WallpaperType.depth,
      'video' || 'live' => WallpaperType.live,
      _ => WallpaperType.unknown,
    };
  }

  /// The value to send back to the API.
  String get wire => switch (this) {
    WallpaperType.normal => 'standard',
    WallpaperType.depth => 'depth',
    WallpaperType.live => 'video',
    WallpaperType.unknown => 'unknown',
  };

  /// Whether this build can actually render and apply the type.
  bool get isSupported => this != WallpaperType.unknown;
}
