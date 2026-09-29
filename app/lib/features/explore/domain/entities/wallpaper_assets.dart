import 'package:equatable/equatable.dart';

/// One stored asset as returned in the detail response's `assets` map, keyed by
/// its kind (`ORIGINAL`, `BACKGROUND`, `FOREGROUND`, `THUMBNAIL`, `PREVIEW`,
/// `VIDEO_LOOP`, `POSTER`, …).
class RemoteAsset extends Equatable {
  const RemoteAsset({
    required this.url,
    required this.mime,
    this.width,
    this.height,
    this.bytes = 0,
  });

  final String url;
  final String mime;
  final int? width;
  final int? height;
  final int bytes;

  @override
  List<Object?> get props => [url, mime, width, height, bytes];
}

/// Well-known asset kinds. Kept as constants rather than an enum because the
/// server may add kinds we do not know about, and the map must survive that.
class AssetKind {
  const AssetKind._();

  static const original = 'ORIGINAL';
  static const mask = 'MASK';
  static const foreground = 'FOREGROUND';
  static const background = 'BACKGROUND';
  static const thumbnail = 'THUMBNAIL';
  static const preview = 'PREVIEW';

  /// The server-rendered composite for the wallpaper's APPROVED studio look:
  /// `PREVIEW` (or, for DEPTH, the same composite `PREVIEW` already is - see
  /// its own doc) with `studio.scene`'s colour grade baked in on top. Queued
  /// by `POST /admin/wallpapers/{id}/studio/render` whenever the grade
  /// changes; its URL embeds a content hash, so a re-bake is a new URL and
  /// old copies (cached or CDN-fronted) are never confused with the new one.
  ///
  /// Verified against production for BOTH generations this backend has
  /// composited a wallpaper with: for STANDARD (`red-earth`) it is the plain
  /// photo plus ONLY the scene grade - `clock`/`dateWidget`/`widgets`, though
  /// authored and enabled, are never baked in, so Details must still draw
  /// them live. For DEPTH (`chatgpt-image-14-...`) it already inherits
  /// `PREVIEW`'s baked clock+date (that composite predates `studio` and was
  /// never scene-only) with the grade added on top, so nothing further needs
  /// drawing there. See `WallpaperEntity.resolveDetailsVisual`.
  static const styledPreview = 'STYLED_PREVIEW';
  static const videoSource = 'VIDEO_SOURCE';
  static const videoLoop = 'VIDEO_LOOP';
  static const poster = 'POSTER';
}

/// The looping video behind a [WallpaperType.live] wallpaper.
class VideoAsset extends Equatable {
  const VideoAsset({
    required this.url,
    required this.mime,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fps,
    required this.sizeBytes,
    required this.codec,
  });

  final String url;

  /// Always `video/mp4` in the current contract.
  final String mime;

  final int width;
  final int height;
  final int durationMs;
  final double fps;
  final int sizeBytes;
  final String codec;

  double get aspectRatio => height == 0 ? 1 : width / height;

  @override
  List<Object?> get props => [
    url,
    mime,
    width,
    height,
    durationMs,
    fps,
    sizeBytes,
    codec,
  ];
}

/// How the foreground layer of a depth wallpaper is placed over the background.
///
/// Distinct from `DepthConfigEntity`, which records the *user's* per-wallpaper
/// on/off choice. This one is authored by the content team and shipped by the
/// backend, so it must never be invented on-device.
class DepthRenderConfig extends Equatable {
  const DepthRenderConfig({
    this.foregroundScale = 1.0,
    this.foregroundOffsetX = 0.0,
    this.foregroundOffsetY = 0.0,
    this.blurRadius = 0.0,
    this.shadowStrength = 0.0,
  });

  /// 0.5 – 3.0.
  final double foregroundScale;

  /// -1.0 – 1.0, as a fraction of the surface width.
  final double foregroundOffsetX;

  /// -1.0 – 1.0, as a fraction of the surface height.
  final double foregroundOffsetY;

  /// 0 – 100, applied to the background behind the subject.
  final double blurRadius;

  /// 0.0 – 1.0.
  final double shadowStrength;

  static const defaults = DepthRenderConfig();

  @override
  List<Object?> get props => [
    foregroundScale,
    foregroundOffsetX,
    foregroundOffsetY,
    blurRadius,
    shadowStrength,
  ];
}
