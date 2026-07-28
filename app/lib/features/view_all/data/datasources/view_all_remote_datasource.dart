import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/paginated_parser.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/data/models/wallpaper_model.dart';
import '../../domain/entities/view_all_options.dart';

abstract class ViewAllRemoteDatasource {
  Future<Paginated<WallpaperModel>> getSectionWallpapers({
    required String section,
    int page = 1,
    int limit = 20,
    FilterOptions? filter,
    SortOption? sort,
  });
}

class ViewAllRemoteDatasourceImpl implements ViewAllRemoteDatasource {
  ViewAllRemoteDatasourceImpl(this._client);

  final DioClient _client;

  @override
  Future<Paginated<WallpaperModel>> getSectionWallpapers({
    required String section,
    int page = 1,
    int limit = 20,
    FilterOptions? filter,
    SortOption? sort,
  }) async {
    final (path, query) = _resolve(section, page, limit, filter, sort);
    try {
      final res = await _client.dio.get(path, queryParameters: query);
      return parsePaginatedResponse(
        res.data as Map<String, dynamic>,
        WallpaperModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.error is Exception ? e.error as Exception : const ServerException();
    }
  }

  (String, Map<String, dynamic>) _resolve(
    String section,
    int page,
    int limit,
    FilterOptions? filter,
    SortOption? sort,
  ) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (sort != null) query['sort'] = sort.value;
    switch (section) {
      case 'trending':
        return ('/wallpapers/trending', query);
      case 'latest':
        return ('/wallpapers/latest', query);
      case 'all':
        if (filter != null) {
          if (filter.categoryIds.isNotEmpty) {
            query['category'] = filter.categoryIds.join(',');
          }
          if (filter.orientation != WallpaperOrientation.all) {
            query['orientation'] = filter.orientation.value;
          }
        }
        return ('/wallpapers', query);
      default:
        return ('/categories/$section/wallpapers', query);
    }
  }
}

class ViewAllMockDatasource implements ViewAllRemoteDatasource {
  @override
  Future<Paginated<WallpaperModel>> getSectionWallpapers({
    required String section,
    int page = 1,
    int limit = 20,
    FilterOptions? filter,
    SortOption? sort,
  }) async {
    final catalog = await MockCatalog.load();
    await Future.delayed(const Duration(milliseconds: 200));
    final sortValue = sort?.value;
    switch (section) {
      case 'trending':
        return catalog.trending(page: page, limit: limit);
      case 'latest':
        return catalog.latest(page: page, limit: limit);
      case 'all':
        final categoryId =
            (filter != null && filter.categoryIds.isNotEmpty)
                ? filter.categoryIds.first
                : null;
        return catalog.all(
            page: page, limit: limit, sort: sortValue, categoryId: categoryId);
      default:
        return catalog.byCategory(section,
            page: page, limit: limit, sort: sortValue);
    }
  }
}
