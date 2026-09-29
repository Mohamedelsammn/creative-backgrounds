import 'package:dio/dio.dart';

import '../../../../core/categories/category_directory.dart';
import '../../domain/entities/wallpaper_type.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/paginated_parser.dart';
import '../../../../core/pagination/paginated.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';

/// How the feed should be ordered. Mirrors the API's `sort` enum exactly -
/// sending anything else is rejected with `VALIDATION_FAILED`.
enum FeedSort {
  /// Editorially ordered. The API's default.
  curated('curated'),

  /// Newest published first - what the app calls "Latest".
  newest('newest'),

  /// Most downloaded first - what the app calls "Trending".
  popular('popular');

  const FeedSort(this.wire);
  final String wire;
}

/// The single place that speaks to the public wallpaper API.
///
/// Explore, View All, Search and Details all funnel through here so the
/// endpoint shapes, query-parameter names and error unwrapping exist once
/// rather than four times.
///
/// Two things about this API drive the design:
///
///  * The feed is **keyset paginated** (`cursor` / `meta.nextCursor`), not
///    offset paginated. Callers continue a listing by passing the previous
///    page's [Paginated.nextCursor].
///  * Feed rows omit the depth layers unless the request asks for them. The
///    only accepted value of `include` is `depth` (verified against the live
///    server), and it is always sent so the app can tell a depth wallpaper from
///    a standard one without a second round trip.
class WallpaperFeedApi {
  WallpaperFeedApi(this._client, this._categories);

  final DioClient _client;
  final CategoryDirectory _categories;

  /// The only value the `include` parameter accepts.
  static const String _includeDepth = 'depth';

  /// `GET /wallpapers` - the published feed.
  Future<Paginated<WallpaperModel>> feed({
    FeedSort sort = FeedSort.curated,
    int limit = 20,
    String? cursor,
    String? categorySlug,
    bool? featured,
    bool? premium,
    WallpaperType? type,
    bool includeVideo = true,
  }) async {
    return _guard(() async {
      final res = await _client.dio.get<dynamic>(
        '/wallpapers',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'sort': sort.wire,
          'include': _includeDepth,
          // Video wallpapers are excluded by default server-side; the app is a
          // first-class consumer of them, so ask for them explicitly.
          'includeVideo': includeVideo.toString(),
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          if (categorySlug != null && categorySlug.isNotEmpty)
            'categorySlug': categorySlug,
          if (featured != null) 'featured': featured.toString(),
          if (premium != null) 'premium': premium.toString(),
          // The schema declares the filter in UPPER CASE
          // (STANDARD|DEPTH|VIDEO) even though responses come back lower-cased,
          // so send the declared form.
          if (type != null && type.isSupported) 'type': type.wire.toUpperCase(),
        },
      );
      return _parsePage(res.data);
    });
  }

  /// `GET /search` - title search. Returns a single unpaginated page; the API
  /// caps `limit` at 50 and reports no cursor.
  Future<Paginated<WallpaperModel>> search(
    String query, {
    int limit = 50,
    bool includeVideo = true,
  }) async {
    // The API rejects anything shorter than two characters; answering locally
    // avoids a guaranteed 400.
    final q = query.trim();
    if (q.length < 2) return const Paginated.empty();

    return _guard(() async {
      final res = await _client.dio.get<dynamic>(
        '/search',
        queryParameters: <String, dynamic>{
          'q': q,
          'limit': limit.clamp(1, 50),
          'includeVideo': includeVideo.toString(),
        },
      );
      return _parsePage(res.data);
    });
  }

  /// `GET /wallpapers/{idOrSlug}` - one published wallpaper, with its assets.
  ///
  /// [previous] is the list row the user tapped, when known: the detail
  /// contract omits `downloads`, `fileSizeBytes` and `blurhash`, so carrying
  /// the row forward keeps those values on screen.
  Future<WallpaperModel> detail(
    String idOrSlug, {
    WallpaperModel? previous,
  }) async {
    return _guard(() async {
      final res = await _client.dio.get<dynamic>('/wallpapers/$idOrSlug');
      final data = res.data;
      if (data is! Map) {
        throw const ServerException('Malformed detail response');
      }
      return WallpaperModel.fromApiDetail(
        Map<String, dynamic>.from(data),
        previous: previous,
      );
    });
  }

  /// `GET /wallpapers/{idOrSlug}/related` - up to ten siblings.
  Future<List<WallpaperModel>> related(String idOrSlug) async {
    return _guard(() async {
      final res = await _client.dio.get<dynamic>(
        '/wallpapers/$idOrSlug/related',
      );
      return parseDataList(res.data, _feedItem);
    });
  }

  /// `GET /categories` - active categories with published counts.
  Future<List<CategoryModel>> categories() async {
    return _guard(() async {
      final res = await _client.dio.get<dynamic>('/categories');
      final list = parseDataList(res.data, CategoryModel.fromApi);
      // Keep the slug directory current so wallpaper rows can name their
      // category without an extra lookup per row.
      _categories.replaceAll(list);
      return list;
    });
  }

  /// `POST /wallpapers/{idOrSlug}/view` - records a view.
  ///
  /// Analytics only: a failure here must never surface to the user or block
  /// the screen, so it is swallowed.
  Future<void> recordView(String idOrSlug) async {
    try {
      await _client.dio.post<dynamic>('/wallpapers/$idOrSlug/view');
    } catch (_) {
      // Intentionally ignored.
    }
  }

  /// `POST /wallpapers/{idOrSlug}/download` - checks entitlement and mints a
  /// single-use link.
  ///
  /// Throws [PaymentRequiredException] when the wallpaper is premium and the
  /// caller is not entitled.
  Future<String> downloadUrl(String idOrSlug) async {
    return _guard(() async {
      final res = await _client.dio.post<dynamic>(
        '/wallpapers/$idOrSlug/download',
      );
      final data = res.data;
      final url = data is Map ? data['downloadUrl'] : null;
      if (url is! String || url.isEmpty) {
        throw const ServerException('Malformed download response');
      }
      return url;
    });
  }

  // --- internals ---------------------------------------------------------

  Paginated<WallpaperModel> _parsePage(Object? data) {
    if (data is! Map) return const Paginated.empty();
    return parsePaginatedResponse(Map<String, dynamic>.from(data), _feedItem);
  }

  WallpaperModel _feedItem(Map<String, dynamic> json) =>
      WallpaperModel.fromApiFeedItem(json, resolveCategory: _categories.lookup);

  /// Unwraps the typed exception `ApiInterceptor` attaches to `err.error`, so
  /// repositories see a data-layer exception rather than a Dio one.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final error = e.error;
      if (error is Exception) throw error;
      throw const ServerException();
    }
  }
}
