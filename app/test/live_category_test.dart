import 'dart:io';

import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/features/categories/domain/live_category.dart';
import 'package:creativebackground/features/categories/presentation/bloc/category_details_bloc.dart';
import 'package:creativebackground/features/categories/presentation/pages/categories_page.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/explore/domain/repositories/explore_repository.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_category_wallpapers_usecase.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_live_wallpapers_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Live Wallpapers" is a CLIENT-SIDE pseudo-category (see [LiveCategory]):
/// live-ness is a property of the wallpaper (`WallpaperType.live`), not a
/// taxonomy bucket. `CategoryDetailsBloc` recognises its reserved slug and
/// serves it from the existing SERVER-SIDE `type=video` feed, so pages stay
/// full and pagination stays correct - rather than fetching mixed pages and
/// dropping non-live items client-side.
void main() {
  group('the Live tile', () {
    test('exists and is named "Live Wallpapers"', () {
      expect(LiveCategory.entity.name, 'Live Wallpapers');
    });

    test('has an Arabic name so the tab still localizes', () {
      expect(LiveCategory.entity.nameAr, isNotNull);
      expect(LiveCategory.entity.nameAr, isNotEmpty);
    });

    test('uses a reserved slug that cannot collide with a backend category',
        () {
      expect(LiveCategory.slug, '__live__');
    });

    test(
      'has NO bundled cover asset and NO thumbnailUrl - it is entirely '
      'client-side, so it always falls through to the plain accent-colour '
      'fallback rather than shipping a dedicated local image just for it',
      () {
        expect(LiveCategory.entity.thumbnailUrl, isNull);
      },
    );

    test(
      'no local category cover assets remain bundled under assets/images/ - '
      'the dashboard is the sole source of category art now',
      () {
        final dir = Directory('assets/images');
        final removedNames = {
          'live.png',
          'nature.png',
          'amoled.png',
          'space.png',
          'Cars.png',
          'Anime.png',
          'minimal.png',
          'abstract.png',
          'animals.png',
        };
        for (final name in removedNames) {
          expect(
            File('${dir.path}/$name').existsSync(),
            isFalse,
            reason: '$name was category-only cover art and must no longer '
                'be packaged',
          );
        }
      },
    );

    test('reports no fabricated wallpaper count', () {
      expect(LiveCategory.entity.wallpaperCount, isNull);
    });
  });

  group('the eight approved categories are an explicit slug allow-list, '
      'decoupled from cover art', () {
    test('exactly the eight expected slugs are approved', () {
      expect(kApprovedCategorySlugs, {
        'nature',
        'amoled',
        'space',
        'cars',
        'anime',
        'minimal',
        'abstract',
        'animals',
      });
    });

    test('Cities has NOT returned', () {
      expect(kApprovedCategorySlugs.contains('cities'), isFalse);
    });
  });

  group('slug routing', () {
    test('the live slug is recognised', () {
      expect(CategoryDetailsBloc.isLiveSlug(LiveCategory.slug), isTrue);
    });

    test('a real backend category slug is not', () {
      expect(kApprovedCategorySlugs, hasLength(8));
      for (final slug in kApprovedCategorySlugs) {
        expect(CategoryDetailsBloc.isLiveSlug(slug), isFalse);
      }
    });
  });

  group('the Live category serves live-only wallpapers', () {
    late _FakeRepository repo;

    CategoryDetailsBloc build() => CategoryDetailsBloc(
          getWallpapers: GetCategoryWallpapersUseCase(repo),
          getLiveWallpapers: GetLiveWallpapersUseCase(repo),
        );

    setUp(() => repo = _FakeRepository());

    Future<CategoryDetailsState> settle(
      CategoryDetailsBloc bloc,
      CategoryDetailsEvent event,
    ) async {
      bloc.add(event);
      return bloc.stream
          .firstWhere((s) => s is CategoryDetailsLoaded || s is CategoryDetailsError)
          .timeout(const Duration(seconds: 5));
    }

    test('it queries the live feed, never the per-category feed', () async {
      final bloc = build();
      await settle(
        bloc,
        const CategoryDetailsFetchRequested(LiveCategory.slug),
      );
      expect(repo.liveCalls, 1);
      expect(repo.categoryCalls, 0);
      await bloc.close();
    });

    test('a real category still queries the per-category feed', () async {
      final bloc = build();
      await settle(bloc, const CategoryDetailsFetchRequested('nature'));
      expect(repo.categoryCalls, 1);
      expect(repo.liveCalls, 0);
      await bloc.close();
    });

    test('every returned wallpaper is canonically WallpaperType.live',
        () async {
      final bloc = build();
      final state = await settle(
        bloc,
        const CategoryDetailsFetchRequested(LiveCategory.slug),
      );
      final loaded = state as CategoryDetailsLoaded;
      expect(loaded.wallpapers, isNotEmpty);
      for (final w in loaded.wallpapers) {
        expect(w.type, WallpaperType.live);
      }
      await bloc.close();
    });

    test('no STATIC wallpaper appears', () async {
      final bloc = build();
      final state = await settle(
        bloc,
        const CategoryDetailsFetchRequested(LiveCategory.slug),
      );
      final loaded = state as CategoryDetailsLoaded;
      expect(
        loaded.wallpapers.where((w) => w.type == WallpaperType.normal),
        isEmpty,
      );
      await bloc.close();
    });

    test('no DEPTH wallpaper appears - depth is a distinct domain type',
        () async {
      expect(WallpaperType.depth, isNot(WallpaperType.live));
      final bloc = build();
      final state = await settle(
        bloc,
        const CategoryDetailsFetchRequested(LiveCategory.slug),
      );
      final loaded = state as CategoryDetailsLoaded;
      expect(
        loaded.wallpapers.where((w) => w.type == WallpaperType.depth),
        isEmpty,
      );
      await bloc.close();
    });

    test('pagination continues on the live feed and stays live-only',
        () async {
      final bloc = build();
      await settle(
        bloc,
        const CategoryDetailsFetchRequested(LiveCategory.slug),
      );
      bloc.add(const CategoryDetailsLoadMoreRequested());
      final more = await bloc.stream
          .firstWhere(
            (s) => s is CategoryDetailsLoaded && !s.isLoadingMore,
          )
          .timeout(const Duration(seconds: 5)) as CategoryDetailsLoaded;

      expect(repo.liveCalls, 2, reason: 'page two also came from type=video');
      expect(repo.categoryCalls, 0);
      expect(more.wallpapers.length, greaterThan(2));
      for (final w in more.wallpapers) {
        expect(w.type, WallpaperType.live);
      }
      await bloc.close();
    });
  });
}

/// Mirrors the real backend contract: `getLiveWallpapers` is already
/// server-filtered to `type=video`, so it only ever yields live rows, while
/// the per-category feed yields that category's mixed content.
class _FakeRepository implements ExploreRepository {
  int liveCalls = 0;
  int categoryCalls = 0;

  static const _live = [WallpaperType.live, WallpaperType.live];

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLiveWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async {
    liveCalls++;
    final page = cursor == null ? 'a' : 'b';
    return Right(
      Paginated(
        items: [
          for (var i = 0; i < _live.length; i++)
            WallpaperEntity(
              id: '$page$i',
              title: '$page$i',
              category: const CategoryEntity(id: 'c', name: 'Cars', slug: 'cars'),
              type: WallpaperType.live,
              thumbnailUrl: 'https://cdn.test/$page$i.webp',
              fullUrl: 'https://cdn.test/$page$i.webp',
              resolution: '1080x1920',
            ),
        ],
        page: cursor == null ? 1 : 2,
        hasMore: cursor == null,
        nextCursor: cursor == null ? 'CURSOR' : null,
      ),
    );
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    categoryCalls++;
    return const Right(Paginated.empty());
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({
    String? cursor,
    bool forceRefresh = false,
  }) async => const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getDepthWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async => const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getNewWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async => const Right(Paginated.empty());

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool forceRefresh = false,
  }) async => const Right([]);

  @override
  Future<Either<Failure, String?>> getWallpaperVideoUrl(String idOrSlug) async =>
      const Right(null);
}
