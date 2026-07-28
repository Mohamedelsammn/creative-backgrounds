import 'package:dartz/dartz.dart';

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

/// Cache-first Explore repository. Page 1 of trending/latest and the category
/// list are cached in Hive; later pages always hit the datasource. On a network
/// failure a stale cache (if any) is served for offline resilience.
class ExploreRepositoryImpl implements ExploreRepository {
  ExploreRepositoryImpl(this._remote, this._cache);

  final ExploreRemoteDatasource _remote;
  final TimedCache _cache;

  static const _listTtl = Duration(minutes: 30);
  static const _categoriesTtl = Duration(hours: 24);

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({int page = 1}) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheTrending,
      page: page,
      fetch: () => _remote.getTrending(page: page),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLatest({int page = 1}) {
    return _cachedWallpaperPage(
      cacheKey: StorageKeys.cacheLatest,
      page: page,
      fetch: () => _remote.getLatest(page: page),
    );
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    final cached = _cache.read(
      HiveBoxes.cacheMetadata,
      StorageKeys.cacheCategories,
      _categoriesTtl,
    );
    if (cached != null && cached.fresh) {
      return Right(_decodeCategories(cached.data));
    }
    try {
      final categories = await _remote.getCategories();
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
    required int page,
    required Future<Paginated<WallpaperModel>> Function() fetch,
  }) async {
    // Only page 1 is cached.
    final cached = page == 1
        ? _cache.read(HiveBoxes.cacheMetadata, cacheKey, _listTtl)
        : null;
    if (cached != null && cached.fresh) {
      return Right(_decodeWallpaperPage(cached.data));
    }
    try {
      final result = await fetch();
      if (page == 1) {
        _cache.write(HiveBoxes.cacheMetadata, cacheKey, _encodeWallpaperPage(result));
      }
      return Right(result.map((m) => m.toEntity()));
    } catch (e) {
      if (cached != null) return Right(_decodeWallpaperPage(cached.data));
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }

  // ---- (de)serialization helpers ------------------------------------------

  Map<String, dynamic> _encodeWallpaperPage(Paginated<WallpaperModel> page) => {
        'items': page.items.map((w) => w.toJson()).toList(),
        'page': page.page,
        'hasMore': page.hasMore,
        'total': page.total,
      };

  Paginated<WallpaperEntity> _decodeWallpaperPage(Object? data) {
    final map = data as Map<String, dynamic>;
    final items = (map['items'] as List)
        .map((e) => WallpaperModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
    return Paginated<WallpaperEntity>(
      items: items,
      page: (map['page'] as num?)?.toInt() ?? 1,
      hasMore: map['hasMore'] as bool? ?? false,
      total: (map['total'] as num?)?.toInt() ?? items.length,
    );
  }

  List<CategoryEntity> _decodeCategories(Object? data) {
    return (data as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }
}

extension _PaginatedMap<T> on Paginated<T> {
  Paginated<R> map<R>(R Function(T) f) => Paginated<R>(
        items: items.map(f).toList(),
        page: page,
        hasMore: hasMore,
        total: total,
      );
}
