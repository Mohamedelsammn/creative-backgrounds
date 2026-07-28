import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/paginated_parser.dart';
import '../../../../core/pagination/paginated.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';

/// Remote contract for the Explore feature. Two implementations exist: a real
/// Dio-backed one (`ExploreRemoteDatasourceImpl`) and a fixture-backed one
/// (`ExploreMockDatasource`); DI selects between them via `AppConfig.mockApi`.
abstract class ExploreRemoteDatasource {
  Future<Paginated<WallpaperModel>> getTrending({int page = 1, int limit = 10});
  Future<Paginated<WallpaperModel>> getLatest({int page = 1, int limit = 10});
  Future<List<CategoryModel>> getCategories();
}

class ExploreRemoteDatasourceImpl implements ExploreRemoteDatasource {
  ExploreRemoteDatasourceImpl(this._client);

  final DioClient _client;

  @override
  Future<Paginated<WallpaperModel>> getTrending({int page = 1, int limit = 10}) {
    return _getWallpaperPage('/wallpapers/trending', page: page, limit: limit);
  }

  @override
  Future<Paginated<WallpaperModel>> getLatest({int page = 1, int limit = 10}) {
    return _getWallpaperPage('/wallpapers/latest', page: page, limit: limit);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _client.dio.get('/categories');
      final data = (res.data['data'] as List? ?? const [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return data;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Paginated<WallpaperModel>> _getWallpaperPage(
    String path, {
    required int page,
    required int limit,
  }) async {
    try {
      final res = await _client.dio.get(
        path,
        queryParameters: {'page': page, 'limit': limit},
      );
      return parsePaginatedResponse(
        res.data as Map<String, dynamic>,
        WallpaperModel.fromJson,
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// The interceptor attaches a typed exception on `err.error`; fall back to a
  /// generic ServerException otherwise.
  Object _unwrap(DioException e) =>
      e.error is Exception ? e.error as Exception : const ServerException();
}
