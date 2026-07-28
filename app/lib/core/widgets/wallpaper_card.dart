import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_text_styles.dart';
import 'pro_badge.dart';

/// Reusable wallpaper card for carousels and grids.
///
/// Sizing is controlled by the parent (SizedBox / grid cell / AspectRatio);
/// this widget fills the space it's given. A bottom gradient guarantees text
/// legibility over any wallpaper.
class WallpaperCard extends StatelessWidget {
  const WallpaperCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.category,
    this.categoryColor,
    this.isPremium = false,
    this.onTap,
    this.heroTag,
    this.borderRadius,
  });

  final String imageUrl;
  final String title;
  final String category;
  final Color? categoryColor;
  final bool isPremium;
  final VoidCallback? onTap;
  final Object? heroTag;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppShapes.card;
    // Cap decoded resolution to the card's pixel size so grids/carousels don't
    // hold full-resolution thumbnails in memory.
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final cacheW = (constraints.maxWidth * dpr).round();
        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: cacheW > 0 ? cacheW : null,
          fadeInDuration: const Duration(milliseconds: 250),
          placeholder: (context, url) =>
              Container(color: const Color(0xFFEDEDED)),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFFE4E4E4),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.textSecondary),
          ),
        );
      },
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

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
                        color: categoryColor ??
                            Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium)
                const Positioned(top: 12, right: 12, child: ProBadge()),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
