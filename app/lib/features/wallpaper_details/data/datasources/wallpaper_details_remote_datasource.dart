import '../../../../core/error/exceptions.dart';
import '../../../../core/fixtures/mock_catalog.dart';
import '../../../explore/data/datasources/wallpaper_feed_api.dart';
import '../../../explore/data/models/wallpaper_model.dart';

/// Fetches a single wallpaper's full detail.
abstract class WallpaperDetailsRemoteDatasource {
  Future<WallpaperModel> getWallpaperDetails(String idOrSlug);

  /// Records a view. Fire-and-forget; never throws.
  Future<void> recordView(String idOrSlug);
}

class WallpaperDetailsRemoteDatasourceImpl
    implements WallpaperDetailsRemoteDatasource {
  WallpaperDetailsRemoteDatasourceImpl(this._api);

  final WallpaperFeedApi _api;

  /// The route parameter is `idOrSlug`, so a deep link by slug and a tap from
  /// a list (which carries the id) both resolve here.
  @override
  Future<WallpaperModel> getWallpaperDetails(String idOrSlug) =>
      _api.detail(idOrSlug);

  @override
  Future<void> recordView(String idOrSlug) => _api.recordView(idOrSlug);
}

class WallpaperDetailsMockDatasource
    implements WallpaperDetailsRemoteDatasource {
  @override
  Future<WallpaperModel> getWallpaperDetails(String idOrSlug) async {
    final catalog = await MockCatalog.load();
    final wallpaper = catalog.byIdOrSlug(idOrSlug);
    if (wallpaper == null) throw const NotFoundException();
    return wallpaper;
  }

  @override
  Future<void> recordView(String idOrSlug) async {}
}
