import 'package:flutter/material.dart';

import '../../domain/entities/wallpaper_entity.dart';
import 'peek_carousel.dart';

/// Trending section carousel (large portrait hero cards with PRO badges).
class TrendingCarousel extends StatelessWidget {
  const TrendingCarousel({
    super.key,
    required this.wallpapers,
    required this.onTap,
  });

  final List<WallpaperEntity> wallpapers;
  final void Function(WallpaperEntity wallpaper, String heroTag) onTap;

  @override
  Widget build(BuildContext context) {
    return PeekCarousel(
      wallpapers: wallpapers,
      heroPrefix: 'trending_hero',
      viewportFraction: 0.72,
      onTap: onTap,
    );
  }
}
