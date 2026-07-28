import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/pagination/paginated.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';
import 'explore_remote_datasource.dart';

/// Fixture-backed Explore datasource used when `AppConfig.mockApi` is true.
class ExploreMockDatasource implements ExploreRemoteDatasource {
  @override
  Future<Paginated<WallpaperModel>> getTrending({int page = 1, int limit = 10}) async {
    final catalog = await MockCatalog.load();
    return catalog.trending(page: page, limit: limit);
  }

  @override
  Future<Paginated<WallpaperModel>> getLatest({int page = 1, int limit = 10}) async {
    final catalog = await MockCatalog.load();
    return catalog.latest(page: page, limit: limit);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final catalog = await MockCatalog.load();
    return catalog.categories;
  }
}
