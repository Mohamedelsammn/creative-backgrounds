import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../features/explore/data/models/category_model.dart';
import '../../features/explore/data/models/wallpaper_model.dart';
import '../../features/explore/domain/entities/wallpaper_type.dart';
import '../categories/category_directory.dart';
import '../pagination/paginated.dart';

/// In-memory catalog backing the `MOCK_API` datasources.
///
/// `assets/fixtures/catalog.json` is written in the **real public-API shape**
/// and parsed through the same `WallpaperModel.fromApiFeedItem` /
/// `fromApiDetail` path as live responses. That is deliberate: the offline mode
/// exercises production parsing rather than a parallel format that could drift
/// away from it, so a mapping bug shows up here too.
class MockCatalog {
  MockCatalog._(this.wallpapers, this.categories, this._details);

  final List<WallpaperModel> wallpapers;
  final List<CategoryModel> categories;

  /// Extra per-wallpaper fields the detail endpoint would add (`assets`,
  /// `description`), keyed by wallpaper id.
  final Map<String, Map<String, dynamic>> _details;

  static MockCatalog? _instance;
  static Future<MockCatalog>? _loading;

  /// Loads (and caches) the catalog. Safe to call concurrently.
  static Future<MockCatalog> load() {
    final cached = _instance;
    if (cached != null) return Future.value(cached);
    return _loading ??= _loadFromAsset().then((c) {
      _instance = c;
      _loading = null;
      return c;
    });
  }

  /// Drops the cached instance. Used by tests that swap the fixture.
  static void reset() {
    _instance = null;
    _loading = null;
  }

  static Future<MockCatalog> _loadFromAsset() async {
    final raw = await rootBundle.loadString('assets/fixtures/catalog.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final categories = ((json['categories'] as Map?)?['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CategoryModel.fromApi(Map<String, dynamic>.from(e)))
        .toList();

    // Resolve category slugs exactly as the live path does.
    final directory = CategoryDirectory()..replaceAll(categories);

    final wallpapers = ((json['wallpapers'] as Map?)?['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => WallpaperModel.fromApiFeedItem(
              Map<String, dynamic>.from(e),
              resolveCategory: directory.lookup,
            ))
        .toList();

    final details = <String, Map<String, dynamic>>{};
    (json['details'] as Map?)?.forEach((key, value) {
      if (value is Map) details['$key'] = Map<String, dynamic>.from(value);
    });

    return MockCatalog._(wallpapers, categories, details);
  }

  // ---- Queries -------------------------------------------------------------

  /// Trending mirrors the live API's `curated` sort + `featured: true` filter:
  /// the order the content team authored, restricted to rows they flagged
  /// `isFeatured`. The fixture array order IS that authored order, so this
  /// deliberately does not re-sort - sorting here would hide a regression where
  /// the app reorders editorial content on the device. `isPremium` never
  /// factors into membership here - it is a separate, unrelated paywall flag.
  Paginated<WallpaperModel> trending({int page = 1, int limit = 10}) {
    final featured = wallpapers.where((w) => w.isFeatured).toList();
    return _paginate(featured, page, limit);
  }

  Paginated<WallpaperModel> latest({int page = 1, int limit = 10}) {
    final sorted = [...wallpapers]..sort(_byNewest);
    return _paginate(sorted, page, limit);
  }

  /// Live (video) wallpapers only, newest first - the fixture equivalent of the
  /// live API's `type=VIDEO` filter, so offline mode exercises the same
  /// contract rather than showing a mixed list. [categorySlug] mirrors the
  /// View All category chips, which combine the live-only constraint with a
  /// category filter server-side.
  Paginated<WallpaperModel> liveWallpapers({
    int page = 1,
    int limit = 10,
    String? categorySlug,
  }) {
    var live = wallpapers
        .where((w) => WallpaperType.fromWire(w.type) == WallpaperType.live)
        .toList();
    if (categorySlug != null && categorySlug.isNotEmpty) {
      live = live
          .where((w) =>
              w.category.slug == categorySlug || w.category.id == categorySlug)
          .toList();
    }
    live.sort(_byNewest);
    return _paginate(live, page, limit);
  }

  /// Depth wallpapers only, newest first - the fixture equivalent of the live
  /// API's `type=DEPTH` filter.
  Paginated<WallpaperModel> depthWallpapers({
    int page = 1,
    int limit = 10,
    String? categorySlug,
  }) {
    var depth = wallpapers
        .where((w) => WallpaperType.fromWire(w.type) == WallpaperType.depth)
        .toList();
    if (categorySlug != null && categorySlug.isNotEmpty) {
      depth = depth
          .where((w) =>
              w.category.slug == categorySlug || w.category.id == categorySlug)
          .toList();
    }
    depth.sort(_byNewest);
    return _paginate(depth, page, limit);
  }

  Paginated<WallpaperModel> all({
    int page = 1,
    int limit = 20,
    String? sort,
    String? categorySlug,
  }) {
    var list = [...wallpapers];
    if (categorySlug != null && categorySlug.isNotEmpty) {
      list = list
          .where((w) =>
              w.category.slug == categorySlug || w.category.id == categorySlug)
          .toList();
    }
    list.sort(_sorter(sort));
    return _paginate(list, page, limit);
  }

  Paginated<WallpaperModel> byCategory(
    String categorySlug, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      all(page: page, limit: limit, sort: sort, categorySlug: categorySlug);

  Paginated<WallpaperModel> search(String query, {int page = 1, int limit = 20}) {
    final q = query.trim().toLowerCase();
    final list = wallpapers.where((w) {
      return w.title.toLowerCase().contains(q) ||
          w.category.name.toLowerCase().contains(q) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
    return _paginate(list, page, limit);
  }

  /// Resolves by id or public slug, mirroring the live `idOrSlug` route, and
  /// layers on the fixture's detail-only fields so the offline detail screen
  /// carries `assets` and `description` just like the real one.
  WallpaperModel? byIdOrSlug(String idOrSlug) {
    for (final w in wallpapers) {
      if (w.id != idOrSlug && w.slug != idOrSlug) continue;
      final extra = _details[w.id];
      if (extra == null) {
        return w.copyWith(isDetailed: true);
      }
      return w.copyWith(
        isDetailed: true,
        assets: Map<String, dynamic>.from(extra['assets'] as Map? ?? const {}),
        description: extra['description'] as String?,
        fullUrl: _originalUrl(extra) ?? w.fullUrl,
      );
    }
    return null;
  }

  static String? _originalUrl(Map<String, dynamic> detail) {
    final assets = detail['assets'];
    if (assets is! Map) return null;
    final original = assets['ORIGINAL'];
    if (original is! Map) return null;
    final url = original['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  int Function(WallpaperModel, WallpaperModel) _sorter(String? sort) {
    switch (sort) {
      case 'latest':
        return _byNewest;
      case 'alphabetical':
        return (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case 'downloads':
      case 'trending':
      default:
        return (a, b) => b.downloadCount.compareTo(a.downloadCount);
    }
  }

  int _byNewest(WallpaperModel a, WallpaperModel b) {
    final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bd.compareTo(ad);
  }

  Paginated<WallpaperModel> _paginate(
    List<WallpaperModel> list,
    int page,
    int limit,
  ) {
    final start = (page - 1) * limit;
    if (start >= list.length) {
      return Paginated(items: const [], page: page, hasMore: false, total: list.length);
    }
    final end = (start + limit).clamp(0, list.length);
    final slice = list.sublist(start, end);
    final hasMore = end < list.length;
    return Paginated(
      items: slice,
      page: page,
      hasMore: hasMore,
      total: list.length,
      // Mirror the live cursor contract so cursor-driven callers work offline.
      nextCursor: hasMore ? 'page:${page + 1}' : null,
    );
  }
}
