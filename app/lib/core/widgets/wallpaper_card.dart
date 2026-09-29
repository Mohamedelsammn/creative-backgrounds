import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_text_styles.dart';
import '../../features/explore/domain/entities/wallpaper_type.dart';
import 'live_wallpaper_player.dart';
import 'live_preview_playback_gate.dart';
import 'pro_badge.dart';
import 'wallpaper_type_badge.dart';

/// Reusable wallpaper card for carousels and grids.
///
/// Sizing is controlled by the parent (SizedBox / grid cell / AspectRatio);
/// this widget fills the space it's given. A bottom gradient guarantees text
/// legibility over any wallpaper.
///
/// Deliberately NOT wrapped in a [Hero]. During a Hero flight the shared child
/// is lifted into the route overlay and removed from both trees, so the
/// destination painted its black Scaffold with no image for the length of the
/// flight - the black screen users reported. The Trending carousel made it
/// worse: it is an infinite `PageView` that renders the same wallpaper at
/// several indices at once, which put duplicate Hero tags in one tree.
/// Navigation now uses a short fade/scale page transition instead.
class WallpaperCard extends StatelessWidget {
  const WallpaperCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.category,
    this.categoryColor,
    this.placeholderColor,
    this.type = WallpaperType.normal,
    this.resolveVideoUrl,
    this.isPremium = false,
    this.onTap,
    this.borderRadius,
    this.livePreviewPlaybackGate,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
  });

  final String imageUrl;
  final String title;
  final String category;
  final Color? categoryColor;

  /// Average colour of the image, from the backend's `dominantColor`. Used as
  /// the loading placeholder so a card fades in from roughly the right hue
  /// instead of flashing grey.
  final Color? placeholderColor;

  /// Marks depth/live wallpapers so a card reads as more than a flat image.
  final WallpaperType type;

  /// Resolves the looping clip for a [WallpaperType.live] card.
  ///
  /// The feed does not carry clip URLs, so this is called lazily - only once
  /// the card is actually visible and about to play. Null means "no clip",
  /// and the card stays a plain image.
  final Future<String?> Function()? resolveVideoUrl;

  final bool isPremium;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// Shared by Home cards so a fast vertical scroll can stop all previews
  /// without rebuilding the containing sections.
  final LivePreviewPlaybackGate? livePreviewPlaybackGate;

  /// Source aspect ratio metadata from the feed. It lets the decoder be
  /// bounded in both dimensions without distorting portrait wallpapers.
  final int sourceWidth;
  final int sourceHeight;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppShapes.card;
    // Cap decoded resolution to the card's pixel size so grids/carousels don't
    // hold full-resolution thumbnails in memory.
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final placeholder = placeholderColor ?? const Color(0xFFEDEDED);

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final boxW = (constraints.maxWidth * dpr).round();
        final boxH = (constraints.maxHeight * dpr).round();
        final sourceAspect = sourceWidth > 0 && sourceHeight > 0
            ? sourceWidth / sourceHeight
            : null;
        final boxAspect = boxW > 0 && boxH > 0 ? boxW / boxH : null;
        var cacheW = boxW;
        int? cacheH;
        if (sourceAspect != null && boxAspect != null) {
          // BoxFit.cover needs enough pixels along the cropped axis. Compute
          // that exact size, rather than decoding the full source or forcing
          // it into the card's (different) aspect ratio.
          if (sourceAspect > boxAspect) {
            cacheH = boxH;
            cacheW = (boxH * sourceAspect).ceil();
          } else {
            cacheH = (boxW / sourceAspect).ceil();
          }
        }
        // A missing or empty URL is a content error, not a network one:
        // short-circuit so CachedNetworkImage never attempts a bad request.
        if (imageUrl.isEmpty) {
          return Container(
            color: placeholder,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textSecondary,
            ),
          );
        }
        // A live wallpaper plays its clip in place of the still image. The
        // player paints the poster underneath and only starts decoding while
        // the card is actually on screen.
        final resolver = resolveVideoUrl;
        if (type == WallpaperType.live && resolver != null) {
          return LiveWallpaperPlayer(
            resolveVideoUrl: resolver,
            posterUrl: imageUrl,
            placeholderColor: placeholderColor,
            // Matches the non-live branch below exactly (same URL, same
            // cap) so both branches share one decoded bitmap in the image
            // cache instead of each holding an independent full-resolution
            // copy of what is, for the poster, the same thumbnail image.
            posterCacheWidth: cacheW > 0 ? cacheW : null,
            posterCacheHeight: cacheH != null && cacheH > 0 ? cacheH : null,
            playbackGate: livePreviewPlaybackGate,
          );
        }
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: cacheW > 0 ? cacheW : null,
          memCacheHeight: cacheH != null && cacheH > 0 ? cacheH : null,
          // Do not run overlapping opacity layers for every image that lands
          // while Home is scrolling. The static placeholder swaps directly
          // to the decoded thumbnail.
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, url) => Container(color: placeholder),
          errorWidget: (context, url, error) => Container(
            color: placeholder,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );

    return Semantics(
      button: true,
      label: '$title, $category wallpaper',
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                // Bottom legibility gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Title + category
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardSubtitle.copyWith(
                          color:
                              categoryColor ??
                              Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPremium)
                  const Positioned(top: 12, right: 12, child: ProBadge()),
                if (WallpaperTypeBadge.showsFor(type))
                  Positioned(
                    top: 12,
                    left: 12,
                    child: WallpaperTypeBadge(type: type),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
