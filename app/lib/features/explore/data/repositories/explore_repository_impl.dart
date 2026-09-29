import 'package:dartz/dartz.dart';

import '../../../../core/categories/category_directory.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/timed_cache.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/explore_repository.dart';
import '../datasources/explore_remote_datasource.dart';
import '../models/category_model.dart';
import '../models/wallpaper_model.dart';

/// Cache-first Explore repository. The first page of trending/latest and the
/// category list are cached in Hive; later pages always hit the datasource. On
/// a network failure a stale cache (if any) is served for offline resilience.
class ExploreRepositoryImpl implements ExploreRepository {
  ExploreRepositoryImpl(this._remote, this._cache, this._categories);

  final ExploreRemoteDatasource _remote;
  final TimedCache _cache;
  final CategoryDirectory _categories;

  static const _listTtl = Duration(minutes: 30);
  static const _categoriesTtl = Duration(hours: 24);

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({
    String? cursor,
    bool forceRefresh = false,
  }) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheTrending,
      cursor: cursor,
      forceRefresh: forceRefresh,
      fetch: () => _remote.getTrending(cursor: cursor),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLiveWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheLiveWallpapers,
      cursor: cursor,
      forceRefresh: forceRefresh,
      fetch: () => _remote.getLiveWallpapers(cursor: cursor),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getDepthWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheDepthWallpapers,
      cursor: cursor,
      forceRefresh: forceRefresh,
      fetch: () => _remote.getDepthWallpapers(cursor: cursor),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getNewWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheLatest,
      cursor: cursor,
      forceRefresh: forceRefresh,
      fetch: () => _remote.getNewWallpapers(cursor: cursor),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    bool forceRefresh = false,
  }) {
    return _cachedWallpaperPage(
      // One cache slot per category, distinct from the trending/live/depth
      // keys and from every other category's own slot.
      cacheKey: '${StorageKeys.cacheCategoryWallpapersPrefix}$categorySlug',
      cursor: cursor,
      forceRefresh: forceRefresh,
      fetch: () => _remote.getCategoryWallpapers(
        categorySlug: categorySlug,
        cursor: cursor,
      ),
    );
  }

  @override
  Future<Either<Failure, String?>> getWallpaperVideoUrl(String idOrSlug) async {
    try {
      final model = await _remote.getWallpaperDetail(idOrSlug);
      return Right(model.toEntity().video?.url);
    } catch (e) {
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool forceRefresh = false,
  }) async {
    final cached = _cache.read(
      HiveBoxes.cacheMetadata,
      StorageKeys.cacheCategories,
      _categoriesTtl,
    );
    if (cached != null && cached.fresh && !forceRefresh) {
      return Right(_decodeCategories(cached.data));
    }
    try {
      final categories = await _remote.getCategories();
      // Keep the slug directory warm even when the datasource is the fixture
      // one, so wallpaper rows can always name their category.
      _categories.replaceAll(categories);
      _cache.write(
        HiveBoxes.cacheMetadata,
        StorageKeys.cacheCategories,
        categories.map((c) => c.toJson()).toList(),
      );
      return Right(categories.map((c) => c.toEntity()).toList());
    } catch (e) {
      if (cached != null) return Right(_decodeCategories(cached.data));
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }

  Future<Either<Failure, Paginated<WallpaperEntity>>> _cachedWallpaperPage({
    required String cacheKey,
    required String? cursor,
    required Future<Paginated<WallpaperModel>> Function() fetch,
    bool forceRefresh = false,
  }) async {
    // Only the first page (no cursor) is cached; a cursor is meaningless
    // without the page that produced it.
    final isFirstPage = cursor == null || cursor.isEmpty;
    final cached = isFirstPage
        ? _cache.read(HiveBoxes.cacheMetadata, cacheKey, _listTtl)
        : null;
    if (cached != null && cached.fresh && !forceRefresh) {
      return Right(_decodeWallpaperPage(cached.data));
    }
    try {
      // Feed rows name their category by slug alone, and that resolution
      // happens while parsing - so the directory has to be warm *before* the
      // fetch, not after it. Without this, a cold start races the parallel
      // category request and rows fall back to a slug-derived name.
      await _ensureCategories();
      final result = await fetch();
      if (isFirstPage) {
        _cache.write(
          HiveBoxes.cacheMetadata,
          cacheKey,
          _encodeWallpaperPage(result),
        );
      }
      return Right(result.map((m) => m.toEntity()));
    } catch (e) {
      if (cached != null) return Right(_decodeWallpaperPage(cached.data));
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }

  /// Guards against two feed requests each triggering their own category
  /// fetch on a cold start: the first caller starts it, the rest await it.
  Future<void>? _categoriesInFlight;

  Future<void> _ensureCategories() async {
    if (!_categories.isEmpty) return;
    // `getCategories` never throws - it returns a Failure - so the shared
    // future always completes and cannot wedge later callers.
    final pending = _categoriesInFlight ??= getCategories().then((_) {});
    try {
      await pending;
    } finally {
      _categoriesInFlight = null;
    }
  }

  // ---- (de)serialization helpers ------------------------------------------

  Map<String, dynamic> _encodeWallpaperPage(Paginated<WallpaperModel> page) => {
    'items': page.items.map((w) => w.toJson()).toList(),
    'page': page.page,
    'hasMore': page.hasMore,
    'total': page.total,
    'nextCursor': page.nextCursor,
  };

  Paginated<WallpaperEntity> _decodeWallpaperPage(Object? data) {
    final map = data as Map<String, dynamic>;
    final items = <WallpaperEntity>[];
    for (final row in (map['items'] as List? ?? const [])) {
      if (row is! Map) continue;
      try {
        items.add(
          WallpaperModel.fromJson(Map<String, dynamic>.from(row)).toEntity(),
        );
      } catch (_) {
        // A cache entry written by an older build can be missing fields the
        // current model requires. Skip that row rather than failing the read;
        // the next successful fetch overwrites the entry.
      }
    }
    return Paginated<WallpaperEntity>(
      items: items,
      page: (map['page'] as num?)?.toInt() ?? 1,
      hasMore: map['hasMore'] as bool? ?? false,
      total: (map['total'] as num?)?.toInt() ?? items.length,
      nextCursor: map['nextCursor'] as String?,
    );
  }

  List<CategoryEntity> _decodeCategories(Object? data) {
    final models = <CategoryModel>[];
    for (final row in (data as List? ?? const [])) {
      if (row is! Map) continue;
      try {
        models.add(CategoryModel.fromJson(Map<String, dynamic>.from(row)));
      } catch (_) {
        // Same rationale as above: tolerate a stale cache shape.
      }
    }
    _categories.replaceAll(models);
    return models.map((c) => c.toEntity()).toList();
  }
}
