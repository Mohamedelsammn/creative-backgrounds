import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/data/datasources/wallpaper_feed_api.dart';
import '../../../explore/data/models/wallpaper_model.dart';

abstract class SearchRemoteDatasource {
  Future<Paginated<WallpaperModel>> search(String query,
      {int page = 1, int limit = 20});
}

class SearchRemoteDatasourceImpl implements SearchRemoteDatasource {
  SearchRemoteDatasourceImpl(this._api);

  final WallpaperFeedApi _api;

  /// The public search endpoint is **not paginated**: it returns a single
  /// ranked page capped at 50 results and reports no cursor. Any page beyond
  /// the first is therefore empty, and the returned page always has
  /// `hasMore == false` so the grid never asks for one.
  @override
  Future<Paginated<WallpaperModel>> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    if (page > 1) return const Paginated.empty();
    return _api.search(query, limit: 50);
  }
}

class SearchMockDatasource implements SearchRemoteDatasource {
  @override
  Future<Paginated<WallpaperModel>> search(String query,
      {int page = 1, int limit = 20}) async {
    final catalog = await MockCatalog.load();
    // Simulate network latency for a realistic debounce/loading feel.
    await Future.delayed(const Duration(milliseconds: 250));
    return catalog.search(query, page: page, limit: limit);
  }
}
