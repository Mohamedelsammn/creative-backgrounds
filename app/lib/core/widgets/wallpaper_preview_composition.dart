import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/clock/domain/entities/studio_design_entity.dart';
import '../../features/clock/presentation/widgets/design_overlay.dart';
import '../../features/depth/presentation/widgets/depth_live_composition.dart';
import '../../features/explore/domain/entities/wallpaper_entity.dart';
import '../../features/explore/domain/entities/wallpaper_type.dart';

/// The single shared "what will this wallpaper actually look like" render,
/// used by BOTH Wallpaper Details and the Apply sheet's preview thumbnail -
/// a fourth independent design renderer is exactly what this widget exists
/// to avoid.
///
/// Reuses [WallpaperEntity.resolveDetailsVisual] for the asset/composition
/// decision (unchanged; the same single source of truth Details already
/// used) and layers one Apply-specific concern on top: [forceSuppressDesign],
/// which represents a "Wallpaper Only" choice the ENTITY itself does not
/// know about (it is a local, in-sheet UI toggle, not part of the persisted
/// wallpaper) - so it is passed in rather than re-derived here.
///
/// STANDARD/DEPTH render identically to Details (a still image, live where
/// the resolver says live). VIDEO deliberately does NOT play here even
/// though Details does: a small Apply-sheet thumbnail has no product reason
/// to pay for a second `MediaPlayer`/decoder (`_ActiveVideoRegistry` caps the
/// app at one concurrent decoder, so a second player here would simply wait
/// indefinitely behind Details' own priority slot when both are visible) -
/// the poster frame (`thumbnailUrl`, which IS the video's own poster) with
/// the live design overlay on top already represents the composition
/// faithfully without that cost.
class WallpaperPreviewComposition extends StatelessWidget {
  const WallpaperPreviewComposition({
    super.key,
    required this.wallpaper,
    this.forceSuppressDesign = false,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final WallpaperEntity wallpaper;

  /// True for a "Wallpaper Only" choice - suppresses the live design overlay
  /// regardless of what [WallpaperEntity.resolveDetailsVisual] would
  /// otherwise draw, mirroring the apply pipeline's own `_suppressDesign`
  /// contract (see `_ApplySheetState`). Never overrides
  /// [WallpaperEntity.resolveDetailsVisual].containsBakedClockAndDate - a
  /// DEPTH composite that already has the clock baked in still shows it,
  /// exactly as "Wallpaper Only" keeps showing a STANDARD wallpaper's own
  /// baked-in scene grade.
  final bool forceSuppressDesign;

  /// `.cover` for the small Apply-sheet card (matches its previous
  /// thumbnail's own fit); Details passes `.contain` to preserve its
  /// letterboxed, never-crop full-bleed presentation.
  final BoxFit fit;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = wallpaper.dominantColor == null
        ? const Color(0xFF15151A)
        : Color(wallpaper.dominantColor!);
    final visual = wallpaper.resolveDetailsVisual();
    final drawClockAndDate =
        visual.drawClockAndDate && !forceSuppressDesign;
    final drawWidgets = visual.drawWidgets && !forceSuppressDesign;

    // Authored `sizePx` (and every other absolute-pixel design value) is
    // dashboard logical pixels against a FULL device screen - confirmed by
    // `DesignOverlay.displayScale`'s own doc, and by Details itself, which
    // passes `displayScale: 1.0` specifically BECAUSE its own render
    // surface is that same full screen (full-bleed `Positioned.fill`). This
    // widget's render surface is whatever box its caller gives it - the
    // ENTIRE screen for Details, a small fixed-height card for the Apply
    // sheet - so `displayScale` must be that box's actual width divided by
    // the full screen's own logical width, not a hardcoded 1.0.
    //
    // `LayoutBuilder` gives the box Flutter actually laid out for THIS
    // widget (after any `SizedBox`/`AspectRatio` from the caller has
    // already been applied), so this is the true rendered size, not an
    // assumed one - the same "actual pixel size" Details' own full-bleed
    // case already gets for free by virtue of filling the screen exactly.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final boxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final displayScale =
            screenWidth > 0 ? (boxWidth / screenWidth).clamp(0.0, 1.0) : 1.0;

        Widget content;
        if (visual.useDepthLiveComposition) {
          // Fills whatever box the caller gives directly - no aspect-locking
          // wrapper. `DepthLiveComposition` already draws its background AND
          // foreground with `.cover` internally (matching the native applied
          // wallpaper's own `DepthCompositor.drawCoverBitmap` geometry,
          // confirmed correct on a physical device), so letting it expand to
          // fill this box is what makes Details show the SAME covered/
          // cropped composition the applied wallpaper actually has, instead
          // of a smaller, aspect-locked box letterboxed in `placeholder` -
          // the same black/empty-looking gap the non-depth branch below was
          // fixed for. Background, design and foreground all live inside
          // `DepthLiveComposition`'s own single `Stack(fit: StackFit.expand)`,
          // so all three still scale and crop together - pixel registration
          // and occlusion are unaffected by this box no longer being
          // aspect-locked.
          content = Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: placeholder),
              forceSuppressDesign
                  // "Wallpaper Only" on a depth wallpaper: still the real
                  // background+foreground composite, just without the design
                  // - reuses `DepthLiveComposition` with an empty design
                  // rather than a second background/foreground stacking
                  // implementation.
                  ? DepthLiveComposition(
                      backgroundUrl: visual.imageUrl,
                      foregroundUrl: visual.foregroundUrl!,
                      design: const StudioDesign(),
                      depthConfig: wallpaper.depthRenderConfig,
                      backgroundFallbackColor: placeholder,
                      displayScale: displayScale,
                    )
                  : DepthLiveComposition(
                      backgroundUrl: visual.imageUrl,
                      foregroundUrl: visual.foregroundUrl!,
                      design: wallpaper.design!,
                      depthConfig: wallpaper.depthRenderConfig,
                      backgroundFallbackColor: placeholder,
                      displayScale: displayScale,
                    ),
            ],
          );
        } else {
          // STANDARD, VIDEO (poster, never played here - see class doc) and
          // any depth fallback (missing a layer, or no design) all share
          // this single flattened-image path, exactly as Details' own
          // non-live branch does.
          final imageUrl = wallpaper.type == WallpaperType.live
              ? wallpaper.thumbnailUrl
              : visual.imageUrl;
          content = Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: placeholder),
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: fit,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) =>
                      const SizedBox.shrink(),
                ),
              if (wallpaper.hasDesign && (drawClockAndDate || drawWidgets))
                Positioned.fill(
                  child: IgnorePointer(
                    child: DesignOverlay(
                      design: wallpaper.design!,
                      displayScale: displayScale,
                      drawClockAndDate: drawClockAndDate,
                      drawWidgets: drawWidgets,
                    ),
                  ),
                ),
            ],
          );
        }

        if (borderRadius != null) {
          content = ClipRRect(borderRadius: borderRadius!, child: content);
        }
        return content;
      },
    );
  }
}

