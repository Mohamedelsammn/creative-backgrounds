import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/widgets/clock_renderer_widget.dart';
import '../../../explore/domain/entities/wallpaper_assets.dart';

/// The canonical depth composite, in the one order that makes the effect work:
///
/// ```
/// BACKGROUND  ->  CLOCK  ->  FOREGROUND
/// ```
///
/// The foreground is the cut-out subject, so painting it last is what puts the
/// clock *behind* it. Any other order produces either a clock hidden entirely
/// or a clock floating on top of the subject.
///
/// Every geometric value comes from the backend's `depthConfig`
/// ([DepthRenderConfig]); nothing here invents a position or a scale. When no
/// config was authored, [DepthRenderConfig.defaults] applies the identity
/// transform, which reproduces the previous behaviour exactly.
class DepthLayerStack extends StatelessWidget {
  const DepthLayerStack({
    super.key,
    required this.backgroundUrl,
    required this.clockConfig,
    this.foregroundUrl,
    this.depthConfig,
    this.showClock = true,
    this.backgroundFallbackColor,
    this.clockLocale,
    this.clockDisplayScale = 1.0,
  });

  final String backgroundUrl;
  final ClockConfigEntity clockConfig;

  /// Forwarded to [ClockRendererWidget.displayScale] - identity for a
  /// full-size render, less than 1.0 for a smaller preview box.
  final double clockDisplayScale;

  /// The cut-out subject. When null (or empty) the composite degrades to
  /// background + clock, which is the correct fallback for a wallpaper whose
  /// foreground failed to load or was never authored.
  final String? foregroundUrl;

  final DepthRenderConfig? depthConfig;
  final bool showClock;
  final Color? backgroundFallbackColor;
  final String? clockLocale;

  bool get _hasForeground => foregroundUrl != null && foregroundUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final config = depthConfig ?? DepthRenderConfig.defaults;
    final fallback = backgroundFallbackColor ?? const Color(0xFF15151A);

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(config, fallback),
        if (showClock)
          Positioned.fill(
            child: IgnorePointer(
              child: ClockRendererWidget(
                config: clockConfig,
                locale: clockLocale,
                displayScale: clockDisplayScale,
              ),
            ),
          ),
        if (_hasForeground) _foreground(config),
      ],
    );
  }

  Widget _background(DepthRenderConfig config, Color fallback) {
    Widget image = CachedNetworkImage(
      imageUrl: backgroundUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => ColoredBox(color: fallback),
      // A missing background is not recoverable here, but it must not blank the
      // screen: fall back to the dominant colour so the clock stays legible.
      errorWidget: (context, url, error) => ColoredBox(color: fallback),
    );

    // The authored blur applies to the plate behind the subject only.
    if (config.blurRadius > 0) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: config.blurRadius,
          sigmaY: config.blurRadius,
        ),
        child: image,
      );
    }
    return Positioned.fill(child: image);
  }

  Widget _foreground(DepthRenderConfig config) {
    Widget subject = CachedNetworkImage(
      imageUrl: foregroundUrl!,
      fit: BoxFit.cover,
      // A foreground that fails to load must vanish silently rather than
      // covering the wallpaper with an error box - the result is simply a
      // non-depth composite.
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );

    if (config.shadowStrength > 0) {
      subject = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: (config.shadowStrength * 0.5).clamp(0.0, 1.0),
              ),
              blurRadius: 24 * config.shadowStrength,
              offset: Offset(0, 8 * config.shadowStrength),
            ),
          ],
        ),
        child: subject,
      );
    }

    // Offsets are normalized fractions of the surface, so the same authored
    // value lands identically on any screen size.
    return Positioned.fill(
      child: FractionalTranslation(
        translation: Offset(
          config.foregroundOffsetX,
          config.foregroundOffsetY,
        ),
        child: Transform.scale(
          scale: config.foregroundScale,
          child: subject,
        ),
      ),
    );
  }
}
