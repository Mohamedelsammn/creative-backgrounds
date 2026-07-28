import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/paginated_parser.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/data/models/wallpaper_model.dart';

abstract class SearchRemoteDatasource {
  Future<Paginated<WallpaperModel>> search(String query,
      {int page = 1, int limit = 20});
}

class SearchRemoteDatasourceImpl implements SearchRemoteDatasource {
  SearchRemoteDatasourceImpl(this._client);

  final DioClient _client;

  @override
  Future<Paginated<WallpaperModel>> search(String query,
      {int page = 1, int limit = 20}) async {
    try {
      final res = await _client.dio.get(
        '/wallpapers/search',
        queryParameters: {'q': query, 'page': page, 'limit': limit},
      );
      return parsePaginatedResponse(
        res.data as Map<String, dynamic>,
        WallpaperModel.fromJson,
      );
    } on DioException catch (e) {
      throw e.error is Exception ? e.error as Exception : const ServerException();
    }
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
