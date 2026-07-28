import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/fixtures/mock_catalog.dart';
import '../../../../core/network/dio_client.dart';
import '../../../explore/data/models/wallpaper_model.dart';

/// Fetches a single wallpaper's full detail.
abstract class WallpaperDetailsRemoteDatasource {
  Future<WallpaperModel> getWallpaperDetails(String id);
}

class WallpaperDetailsRemoteDatasourceImpl
    implements WallpaperDetailsRemoteDatasource {
  WallpaperDetailsRemoteDatasourceImpl(this._client);

  final DioClient _client;

  @override
  Future<WallpaperModel> getWallpaperDetails(String id) async {
    try {
      final res = await _client.dio.get('/wallpapers/$id');
      return WallpaperModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is Exception ? e.error as Exception : const ServerException();
    }
  }
}

class WallpaperDetailsMockDatasource
    implements WallpaperDetailsRemoteDatasource {
  @override
  Future<WallpaperModel> getWallpaperDetails(String id) async {
    final catalog = await MockCatalog.load();
    final wallpaper = catalog.byId(id);
    if (wallpaper == null) throw const NotFoundException();
    return wallpaper;
  }
}
