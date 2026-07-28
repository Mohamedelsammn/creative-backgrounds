import 'package:flutter/material.dart';

import '../../domain/entities/wallpaper_entity.dart';
import 'peek_carousel.dart';

/// Latest section carousel. Same peek behavior as Trending, slightly shorter.
class LatestCarousel extends StatelessWidget {
  const LatestCarousel({
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
      heroPrefix: 'latest_hero',
      viewportFraction: 0.72,
      onTap: onTap,
    );
  }
}
