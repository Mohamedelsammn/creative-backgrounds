import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../features/explore/data/models/category_model.dart';
import '../../features/explore/data/models/wallpaper_model.dart';
import '../pagination/paginated.dart';

/// In-memory catalog backing the `MOCK_API` datasources. Loads
/// `assets/fixtures/catalog.json` once and answers the same queries the real
/// endpoints do (paginate / sort / filter / search).
class MockCatalog {
  MockCatalog._(this.wallpapers, this.categories);

  final List<WallpaperModel> wallpapers;
  final List<CategoryModel> categories;

  static MockCatalog? _instance;
  static Future<MockCatalog>? _loading;

  /// Loads (and caches) the catalog. Safe to call concurrently.
  static Future<MockCatalog> load() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= _loadFromAsset().then((c) {
      _instance = c;
      _loading = null;
      return c;
    });
  }

  static Future<MockCatalog> _loadFromAsset() async {
    final raw = await rootBundle.loadString('assets/fixtures/catalog.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final wallpapers = (json['wallpapers'] as List)
        .map((e) => WallpaperModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final categories = (json['categories'] as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return MockCatalog._(wallpapers, categories);
  }

  // ---- Queries -------------------------------------------------------------

  Paginated<WallpaperModel> trending({int page = 1, int limit = 10}) {
    final sorted = [...wallpapers]
      ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    return _paginate(sorted, page, limit);
  }

  Paginated<WallpaperModel> latest({int page = 1, int limit = 10}) {
    final sorted = [...wallpapers]..sort(_byNewest);
    return _paginate(sorted, page, limit);
  }

  Paginated<WallpaperModel> all({
    int page = 1,
    int limit = 20,
    String? sort,
    String? categoryId,
  }) {
    var list = [...wallpapers];
    if (categoryId != null && categoryId.isNotEmpty) {
      list = list.where((w) => w.category.id == categoryId).toList();
    }
    list.sort(_sorter(sort));
    return _paginate(list, page, limit);
  }

  Paginated<WallpaperModel> byCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
    String? sort,
  }) =>
      all(page: page, limit: limit, sort: sort, categoryId: categoryId);

  Paginated<WallpaperModel> search(String query, {int page = 1, int limit = 20}) {
    final q = query.trim().toLowerCase();
    final list = wallpapers.where((w) {
      return w.title.toLowerCase().contains(q) ||
          w.category.name.toLowerCase().contains(q) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
    return _paginate(list, page, limit);
  }

  WallpaperModel? byId(String id) {
    for (final w in wallpapers) {
      if (w.id == id) return w;
    }
    return null;
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
    return Paginated(
      items: slice,
      page: page,
      hasMore: end < list.length,
      total: list.length,
    );
  }
}
