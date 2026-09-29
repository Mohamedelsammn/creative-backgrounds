import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../clock/domain/entities/studio_design_entity.dart';
import '../../../clock/presentation/widgets/design_overlay.dart';
import '../../../explore/domain/entities/wallpaper_assets.dart';

/// Wallpaper Details' LIVE render of a depth wallpaper: the same
/// background -> design -> foreground composition Apply already produces,
/// so Details never shows a frozen server-baked clock/date again.
///
/// This is deliberately its own widget rather than a reuse of
/// `DepthLayerStack`: that one draws only a bare [ClockConfigEntity] (no
/// date widget, no studio widgets) via a raw `ClockRendererWidget`, and its
/// `Customize`-sheet caller never needed anything more. Details needs the
/// FULL authored [StudioDesign] - clock, independent date widget and
/// widgets like `batteryRing` - which only [DesignOverlay] composes, so this
/// widget draws the same background -> foreground order with [DesignOverlay]
/// standing in for the bare clock.
///
/// Z-order (mirrors `DepthCompositor.kt`'s native draw order exactly):
/// ```
/// BACKGROUND -> DesignOverlay (clock/date/widgets) -> FOREGROUND
/// ```
/// painting the cut-out subject last is what makes it occlude the clock, the
/// same effect the applied wallpaper already shows.
class DepthLiveComposition extends StatelessWidget {
  const DepthLiveComposition({
    super.key,
    required this.backgroundUrl,
    required this.foregroundUrl,
    required this.design,
    this.depthConfig,
    this.clockLocale,
    this.backgroundFallbackColor,
    this.displayScale = 1.0,
  });

  final String backgroundUrl;
  final String foregroundUrl;
  final StudioDesign design;
  final DepthRenderConfig? depthConfig;
  final String? clockLocale;
  final Color? backgroundFallbackColor;

  /// Forwarded to [DesignOverlay.displayScale] - identity for a full-size
  /// render (Details, which fills the whole screen), less than 1.0 for a
  /// smaller preview box (the Apply sheet's own thumbnail). Authored design
  /// values (`sizePx` and friends) are logical pixels against a full
  /// screen, so a smaller render surface must scale them down by the same
  /// fraction or the clock renders far larger than the box that is meant to
  /// contain it - see [DesignOverlay.displayScale]'s own doc.
  final double displayScale;

  /// Opacity of the foreground copy drawn over the clock. No clock (or a
  /// "Wallpaper Only" empty design) means nothing to occlude.
  double get _occlusion {
    final clock = design.clock;
    if (clock == null || !clock.enabled) return 0;
    return (1 - clock.depth).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final config = depthConfig ?? DepthRenderConfig.defaults;
    final fallback = backgroundFallbackColor ?? const Color(0xFF15151A);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The background plate. `.cover`, matching `DepthCompositor.kt`'s own
        // `drawFitBitmap`-style fill of the surface it is given - the
        // enclosing box here is already the letterboxed, aspect-correct
        // wallpaper viewport (see `_DepthLiveViewport`), not the raw phone
        // screen, so `.cover` here does not reintroduce the old crop bug.
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: backgroundUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => ColoredBox(color: fallback),
            errorWidget: (context, url, error) => ColoredBox(color: fallback),
          ),
        ),
        // FLUTTER_RENDERING_GUIDE §2 (DEPTH): background, foreground, the
        // clock, the foreground again at (1 - clock.depth) - that copy is
        // the occlusion - then the date widget and extras on top. Mirrors
        // `LiveWallpaperService.drawFrame`.
        Positioned.fill(child: _Foreground(url: foregroundUrl, config: config)),
        Positioned.fill(
          child: IgnorePointer(
            child: DesignOverlay(
              design: design,
              clockLocale: clockLocale,
              displayScale: displayScale,
              part: DesignOverlayPart.clockOnly,
            ),
          ),
        ),
        if (_occlusion > 0)
          Positioned.fill(
            child: Opacity(
              opacity: _occlusion,
              child: _Foreground(url: foregroundUrl, config: config),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DesignOverlay(
              design: design,
              clockLocale: clockLocale,
              displayScale: displayScale,
              part: DesignOverlayPart.extrasOnly,
            ),
          ),
        ),
      ],
    );
  }
}

class _Foreground extends StatelessWidget {
  const _Foreground({required this.url, required this.config});

  final String url;
  final DepthRenderConfig config;

  @override
  Widget build(BuildContext context) {
    // No shadow wrapper: a BoxShadow shades the image's whole RECTANGLE, not
    // the cut-out subject, so its transparent area showed a dark haze over
    // the artwork. The applied wallpaper (`DepthCompositor.drawForeground`)
    // draws no foreground shadow either.
    final subject = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // A foreground that fails to load must vanish silently rather than
      // covering the design with an error box - matches `DepthLayerStack`.
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );

    // Offsets are normalized fractions of the surface, so the same authored
    // value lands identically on any screen size - mirrors `DepthLayerStack`.
    return FractionalTranslation(
      translation: Offset(config.foregroundOffsetX, config.foregroundOffsetY),
      child: Transform.scale(scale: config.foregroundScale, child: subject),
    );
  }
}
