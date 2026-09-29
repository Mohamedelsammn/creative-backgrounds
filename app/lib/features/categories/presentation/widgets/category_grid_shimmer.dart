import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/mixed_wallpaper_feed_sliver.dart';

/// Skeleton loading state for Category Details, shaped exactly like the
/// real wallpaper grid it is standing in for - same 2 columns, same
/// [kWallpaperCardAspectRatio], same grid spacing, same card radius (via
/// [LoadingShimmer]'s own default). Real content replacing this causes no
/// layout shift, since both use the identical `SliverGridDelegateWithFixed
/// CrossAxisCount` geometry.
///
/// Enough rows are rendered to fill a normal phone screen so the page never
/// looks empty while the first page loads - never a bare centered spinner.
class CategoryGridShimmer extends StatelessWidget {
  const CategoryGridShimmer({super.key});

  // 3 rows x 2 columns fills a typical phone viewport at the new, taller
  // card ratio without overbuilding shimmer widgets that scroll off-screen
  // before real content ever replaces them.
  static const int _placeholderCount = 6;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Matches CategoryDetailsPage's WallpaperGrid padding exactly, so
      // swapping shimmer for real content shifts nothing.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.grid,
        crossAxisSpacing: AppSpacing.grid,
        childAspectRatio: kWallpaperCardAspectRatio,
      ),
      itemCount: _placeholderCount,
      itemBuilder: (context, index) => const LoadingShimmer(),
    );
  }
}
