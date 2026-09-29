import '../../../../core/pagination/paginated.dart';
import '../../domain/entities/wallpaper_type.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';
import 'wallpaper_feed_api.dart';

/// Remote contract for the Explore feature. Two implementations exist: a real
/// API-backed one (`ExploreRemoteDatasourceImpl`) and a fixture-backed one
/// (`ExploreMockDatasource`); DI selects between them via `AppConfig.mockApi`.
///
/// [cursor] continues a keyset-paginated listing. The first page passes null;
/// later pages pass the previous page's `nextCursor`.
abstract class ExploreRemoteDatasource {
  Future<Paginated<WallpaperModel>> getTrending({
    String? cursor,
    int limit = 10,
  });

  /// Live (video) wallpapers only. The type filter is applied server-side so
  /// the app never downloads a page of mixed types and discards most of it -
  /// which would also make pagination lie about how much is left.
  Future<Paginated<WallpaperModel>> getLiveWallpapers({
    String? cursor,
    int limit = 10,
  });

  /// Depth wallpapers only (background + cut-out foreground + clock),
  /// filtered server-side for the same reason as [getLiveWallpapers].
  Future<Paginated<WallpaperModel>> getDepthWallpapers({
    String? cursor,
    int limit = 10,
  });

  /// The whole catalog, newest first, no type filter - normal, depth and
  /// live wallpapers mixed together exactly as the backend orders them.
  /// Backs Explore's single "New Wallpapers" feed.
  Future<Paginated<WallpaperModel>> getNewWallpapers({
    String? cursor,
    int limit = 20,
  });

  Future<List<CategoryModel>> getCategories();

  /// A single category's own wallpapers, filtered server-side by
  /// [categorySlug] - the actual content for that category's Home carousel,
  /// as opposed to whatever happened to already be in the trending/live/depth
  /// pages.
  Future<Paginated<WallpaperModel>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    int limit = 10,
  });

  /// One wallpaper's full detail - the only place the API exposes `video`.
  Future<WallpaperModel> getWallpaperDetail(String idOrSlug);
}

class ExploreRemoteDatasourceImpl implements ExploreRemoteDatasource {
  ExploreRemoteDatasourceImpl(this._api);

  final WallpaperFeedApi _api;

  /// "Trending" is the API's **curated** ordering: the sequence the content
  /// team arranges in the dashboard via each wallpaper's `sortOrder`.
  ///
  /// Deliberately NOT `popular` (download count) - Trending is an editorial
  /// slot, not a leaderboard. The API returns the rows already in the intended
  /// order and this app renders them as received; ordering is never recomputed
  /// on the device.
  ///
  /// `featured: true` is also sent, so membership is the dashboard's
  /// `featured` flag rather than every curated-ordered row - `premium` is a
  /// separate, unrelated flag (paywall gating) and must never affect who
  /// appears here.
  @override
  Future<Paginated<WallpaperModel>> getTrending({
    String? cursor,
    int limit = 10,
  }) => _api.feed(
    sort: FeedSort.curated,
    cursor: cursor,
    limit: limit,
    featured: true,
  );

  @override
  Future<Paginated<WallpaperModel>> getLiveWallpapers({
    String? cursor,
    int limit = 10,
  }) => _api.feed(
    sort: FeedSort.newest,
    cursor: cursor,
    limit: limit,
    type: WallpaperType.live,
    // Video rows are excluded from the feed by default; this section is
    // made of nothing else, so it must opt in explicitly.
    includeVideo: true,
  );

  @override
  Future<Paginated<WallpaperModel>> getDepthWallpapers({
    String? cursor,
    int limit = 10,
  }) => _api.feed(
    sort: FeedSort.newest,
    cursor: cursor,
    limit: limit,
    type: WallpaperType.depth,
  );

  @override
  Future<Paginated<WallpaperModel>> getNewWallpapers({
    String? cursor,
    int limit = 20,
  }) => _api.feed(sort: FeedSort.newest, cursor: cursor, limit: limit);

  @override
  Future<List<CategoryModel>> getCategories() => _api.categories();

  @override
  Future<Paginated<WallpaperModel>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    int limit = 10,
  }) => _api.feed(
    sort: FeedSort.newest,
    cursor: cursor,
    limit: limit,
    categorySlug: categorySlug,
  );

  @override
  Future<WallpaperModel> getWallpaperDetail(String idOrSlug) =>
      _api.detail(idOrSlug);
}
