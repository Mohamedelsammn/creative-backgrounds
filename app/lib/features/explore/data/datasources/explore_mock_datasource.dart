import '../../../../core/error/exceptions.dart';
import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/pagination/paginated.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';
import 'explore_remote_datasource.dart';

/// Fixture-backed Explore datasource used when `AppConfig.mockApi` is true.
class ExploreMockDatasource implements ExploreRemoteDatasource {
  @override
  Future<Paginated<WallpaperModel>> getTrending({
    String? cursor,
    int limit = 10,
  }) async {
    final catalog = await MockCatalog.load();
    return catalog.trending(page: pageFromCursor(cursor), limit: limit);
  }

  @override
  Future<Paginated<WallpaperModel>> getLiveWallpapers({
    String? cursor,
    int limit = 10,
  }) async {
    final catalog = await MockCatalog.load();
    return catalog.liveWallpapers(page: pageFromCursor(cursor), limit: limit);
  }

  @override
  Future<Paginated<WallpaperModel>> getDepthWallpapers({
    String? cursor,
    int limit = 10,
  }) async {
    final catalog = await MockCatalog.load();
    return catalog.depthWallpapers(page: pageFromCursor(cursor), limit: limit);
  }

  @override
  Future<Paginated<WallpaperModel>> getNewWallpapers({
    String? cursor,
    int limit = 20,
  }) async {
    final catalog = await MockCatalog.load();
    return catalog.all(page: pageFromCursor(cursor), limit: limit);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final catalog = await MockCatalog.load();
    return catalog.categories;
  }

  @override
  Future<Paginated<WallpaperModel>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    int limit = 10,
  }) async {
    final catalog = await MockCatalog.load();
    return catalog.byCategory(
      categorySlug,
      page: pageFromCursor(cursor),
      limit: limit,
    );
  }

  @override
  Future<WallpaperModel> getWallpaperDetail(String idOrSlug) async {
    final catalog = await MockCatalog.load();
    final wallpaper = catalog.byIdOrSlug(idOrSlug);
    if (wallpaper == null) throw const NotFoundException();
    return wallpaper;
  }
}

/// Decodes the synthetic `page:N` cursor `MockCatalog` emits, so fixture-backed
/// datasources honour the same cursor contract as the live API. Anything
/// unrecognised (including null) starts at page 1.
int pageFromCursor(String? cursor) {
  if (cursor == null || !cursor.startsWith('page:')) return 1;
  return int.tryParse(cursor.substring(5)) ?? 1;
}
