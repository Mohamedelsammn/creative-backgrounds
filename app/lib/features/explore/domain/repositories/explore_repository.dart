import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../entities/category_entity.dart';
import '../entities/wallpaper_entity.dart';

/// Explore data contract. Implemented in the data layer with Hive caching in
/// front of the remote datasource.
abstract class ExploreRepository {
  /// [cursor] continues a keyset-paginated listing; null loads the first page
  /// (the only one that is cached). [forceRefresh] bypasses (and then
  /// rewrites) the cached first page - used for pull-to-refresh, so a
  /// wallpaper published or unpublished since the last fetch is reflected
  /// without waiting out the TTL. Never affects the image cache.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({
    String? cursor,
    bool forceRefresh = false,
  });

  /// Live (video) wallpapers only, filtered server-side.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLiveWallpapers({
    String? cursor,
    bool forceRefresh = false,
  });

  /// Depth wallpapers only, filtered server-side.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getDepthWallpapers({
    String? cursor,
    bool forceRefresh = false,
  });

  /// The single mixed feed (normal + depth + live together, newest first)
  /// that drives Explore's "New Wallpapers" section - the whole catalog,
  /// unfiltered by type. Category Details reuses [getCategoryWallpapers]
  /// instead, which already filters this same ordering by category.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getNewWallpapers({
    String? cursor,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool forceRefresh = false,
  });

  /// A single category's own wallpapers, server-filtered by [categorySlug] -
  /// the actual content for that category's Home carousel.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    bool forceRefresh = false,
  });

  /// The looping clip URL for a live wallpaper.
  ///
  /// The feed omits the `video` object, so this hits the detail endpoint. Null
  /// when the wallpaper has no clip.
  Future<Either<Failure, String?>> getWallpaperVideoUrl(String idOrSlug);
}
