import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/wallpaper_card.dart';
import '../../domain/entities/wallpaper_entity.dart';

/// A single category section: header + horizontal list of wallpaper cards.
class CategoryCarousel extends StatelessWidget {
  const CategoryCarousel({
    super.key,
    required this.categoryName,
    required this.wallpapers,
    required this.onViewAll,
    required this.onTapWallpaper,
  });

  final String categoryName;
  final List<WallpaperEntity> wallpapers;
  final VoidCallback onViewAll;
  final void Function(WallpaperEntity wallpaper, String heroTag) onTapWallpaper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: SectionHeader(title: categoryName, onViewAll: onViewAll),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            itemCount: wallpapers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final wallpaper = wallpapers[index];
              final heroTag = 'cat_${categoryName}_hero_${wallpaper.id}';
              return SizedBox(
                width: 150,
                child: WallpaperCard(
                  imageUrl: wallpaper.thumbnailUrl,
                  title: wallpaper.title,
                  category: wallpaper.category.name,
                  isPremium: wallpaper.isPremium,
                  heroTag: heroTag,
                  onTap: () => onTapWallpaper(wallpaper, heroTag),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
