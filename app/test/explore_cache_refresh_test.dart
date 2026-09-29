import 'dart:io';

import 'package:creativebackground/core/categories/category_directory.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/core/storage/hive_storage.dart';
import 'package:creativebackground/core/storage/timed_cache.dart';
import 'package:creativebackground/features/explore/data/datasources/explore_remote_datasource.dart';
import 'package:creativebackground/features/explore/data/models/category_model.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/data/repositories/explore_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Proves pull-to-refresh (`forceRefresh: true`) actually reaches the network
/// and rewrites the cache - the bug was that a normal fetch and a
/// pull-to-refresh were the same request, so a wallpaper published or
/// unpublished after the initial load never showed up until the 30-minute TTL
/// expired or "Clear Cache" was used. Uses a real (temp-dir) Hive box, not a
/// mocked cache, so the TTL/freshness logic under test is the real thing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('explore_cache_test_');
    Hive.init(tempDir.path);
    await HiveStorage.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  const category = CategoryModel(id: 'cat-nature', name: 'Nature', slug: 'nature');

  WallpaperModel wallpaper(String id) => WallpaperModel(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
        type: 'standard',
      );

  ExploreRepositoryImpl repo(_FakeRemoteDatasource remote) =>
      ExploreRepositoryImpl(remote, TimedCache(HiveStorage()), CategoryDirectory());

  test(
      'a plain fetch (forceRefresh: false) serves the cached page and never '
      'calls the datasource again', () async {
    final remote = _FakeRemoteDatasource(
      pages: [
        Paginated(items: [wallpaper('a')], page: 1, hasMore: false),
        Paginated(items: [wallpaper('a'), wallpaper('b')], page: 1, hasMore: false),
      ],
    );
    final r = repo(remote);

    final first = await r.getTrending();
    expect(first.getOrElse(() => const Paginated.empty()).items.map((w) => w.id),
        ['a']);
    expect(remote.trendingCallCount, 1);

    // A newly published wallpaper ("b") exists server-side now, but a plain
    // (non-refresh) fetch is still within the TTL and must not re-hit the
    // network - that would defeat the point of caching.
    final second = await r.getTrending();
    expect(second.getOrElse(() => const Paginated.empty()).items.map((w) => w.id),
        ['a']);
    expect(remote.trendingCallCount, 1);
  });

  test(
      'forceRefresh: true bypasses the cache and picks up a newly published '
      'wallpaper without Clear Cache or a restart', () async {
    final remote = _FakeRemoteDatasource(
      pages: [
        Paginated(items: [wallpaper('a')], page: 1, hasMore: false),
        Paginated(items: [wallpaper('a'), wallpaper('b')], page: 1, hasMore: false),
      ],
    );
    final r = repo(remote);

    await r.getTrending();
    expect(remote.trendingCallCount, 1);

    final refreshed = await r.getTrending(forceRefresh: true);
    expect(
      refreshed.getOrElse(() => const Paginated.empty()).items.map((w) => w.id),
      ['a', 'b'],
    );
    expect(remote.trendingCallCount, 2);
  });

  test(
      'forceRefresh: true also picks up a wallpaper removed/unpublished '
      'server-side', () async {
    final remote = _FakeRemoteDatasource(
      pages: [
        Paginated(items: [wallpaper('a'), wallpaper('b')], page: 1, hasMore: false),
        Paginated(items: [wallpaper('a')], page: 1, hasMore: false),
      ],
    );
    final r = repo(remote);

    await r.getTrending();
    final refreshed = await r.getTrending(forceRefresh: true);

    expect(
      refreshed.getOrElse(() => const Paginated.empty()).items.map((w) => w.id),
      ['a'],
    );
  });

  test('a forced refresh rewrites the cache, so the next plain fetch serves '
      'the refreshed data, not the original page', () async {
    final remote = _FakeRemoteDatasource(
      pages: [
        Paginated(items: [wallpaper('a')], page: 1, hasMore: false),
        Paginated(items: [wallpaper('a'), wallpaper('b')], page: 1, hasMore: false),
      ],
    );
    final r = repo(remote);

    await r.getTrending();
    await r.getTrending(forceRefresh: true);
    expect(remote.trendingCallCount, 2);

    final plain = await r.getTrending();
    expect(plain.getOrElse(() => const Paginated.empty()).items.map((w) => w.id),
        ['a', 'b']);
    // Still 2 - the plain fetch was served from the now-updated cache.
    expect(remote.trendingCallCount, 2);
  });

  test('forceRefresh on live wallpapers is independent of the trending cache',
      () async {
    final remote = _FakeRemoteDatasource(
      pages: [Paginated(items: [wallpaper('a')], page: 1, hasMore: false)],
      livePages: [
        Paginated(items: [wallpaper('live-1')], page: 1, hasMore: false),
        Paginated(items: [wallpaper('live-1'), wallpaper('live-2')], page: 1, hasMore: false),
      ],
    );
    final r = repo(remote);

    await r.getTrending();
    await r.getLiveWallpapers();
    expect(remote.trendingCallCount, 1);
    expect(remote.liveCallCount, 1);

    await r.getLiveWallpapers(forceRefresh: true);
    expect(remote.liveCallCount, 2);
    // Refreshing live wallpapers must not force-refetch trending.
    expect(remote.trendingCallCount, 1);
  });
}

class _FakeRemoteDatasource implements ExploreRemoteDatasource {
  _FakeRemoteDatasource({required List<Paginated<WallpaperModel>> pages, List<Paginated<WallpaperModel>>? livePages})
      : _pages = pages,
        _livePages = livePages ?? pages;

  final List<Paginated<WallpaperModel>> _pages;
  final List<Paginated<WallpaperModel>> _livePages;
  int trendingCallCount = 0;
  int liveCallCount = 0;

  @override
  Future<Paginated<WallpaperModel>> getTrending({String? cursor, int limit = 10}) async {
    final page = _pages[trendingCallCount.clamp(0, _pages.length - 1)];
    trendingCallCount++;
    return page;
  }

  @override
  Future<Paginated<WallpaperModel>> getLiveWallpapers({String? cursor, int limit = 10}) async {
    final page = _livePages[liveCallCount.clamp(0, _livePages.length - 1)];
    liveCallCount++;
    return page;
  }

  @override
  Future<Paginated<WallpaperModel>> getDepthWallpapers({String? cursor, int limit = 10}) async {
    return const Paginated.empty();
  }

  @override
  Future<Paginated<WallpaperModel>> getNewWallpapers({String? cursor, int limit = 20}) async {
    return const Paginated.empty();
  }

  @override
  Future<List<CategoryModel>> getCategories() async => const [
        CategoryModel(id: 'cat-nature', name: 'Nature', slug: 'nature'),
      ];

  @override
  Future<Paginated<WallpaperModel>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    int limit = 10,
  }) async =>
      const Paginated.empty();

  @override
  Future<WallpaperModel> getWallpaperDetail(String idOrSlug) =>
      throw UnimplementedError();
}
