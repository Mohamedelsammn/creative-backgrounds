import 'dart:async';

import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/core/widgets/adaptive_banner_ad.dart';
import 'package:creativebackground/core/widgets/loading_shimmer.dart';
import 'package:creativebackground/core/widgets/mixed_wallpaper_feed_sliver.dart';
import 'package:creativebackground/core/widgets/wallpaper_card.dart';
import 'package:creativebackground/features/categories/presentation/bloc/category_details_bloc.dart';
import 'package:creativebackground/features/categories/presentation/pages/category_details_page.dart';
import 'package:creativebackground/features/categories/presentation/widgets/category_grid_shimmer.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/core/usecases/usecase.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_category_wallpapers_usecase.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_live_wallpapers_usecase.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Category Details used to insert an ad after every 6th wallpaper, exactly
/// like Explore - the same shared [buildMixedWallpaperFeedSlivers] call, just
/// with an `adUnitId`/`bannerManagerAt` supplied. Per this correction pass,
/// Category Details must NEVER do that (Explore/Home keeps it - see
/// `explore_scroll_stability_test.dart` and `mixed_wallpaper_feed_uniform_grid
/// _test.dart`, neither of which changes) - instead it shows exactly ONE
/// persistent banner anchored below the grid, never inside the scrollable
/// list.
void main() {
  const category = CategoryEntity(
    id: 'cat-1',
    name: 'Nature',
    slug: 'nature',
    wallpaperCount: 12,
  );

  WallpaperEntity wallpaper(String id) => WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
      );

  final twelveWallpapers = List.generate(12, (i) => wallpaper('w$i'));

  Future<void> pumpPage(
    WidgetTester tester,
    GetCategoryWallpapersUseCase useCase,
  ) async {
    di.sl.registerFactory<CategoryDetailsBloc>(
      () => CategoryDetailsBloc(
        getWallpapers: useCase,
        getLiveWallpapers: _UnusedGetLiveWallpapersUseCase(),
      ),
    );
    final router = GoRouter(
      initialLocation: '/categories/nature',
      routes: [
        GoRoute(
          path: '/categories/:slug',
          builder: (context, state) => CategoryDetailsPage(
            slug: state.pathParameters['slug']!,
            knownCategory: category,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
  }

  tearDown(() => di.sl.reset());

  testWidgets(
      'the loaded wallpaper grid never inserts an ad slot between '
      'wallpapers, even with more than 6 items (Explore keeps this - '
      'Category Details must not)', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(
      tester,
      _FakeGetCategoryWallpapersUseCase(
        Paginated(items: twelveWallpapers, page: 1, hasMore: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperCard), findsNWidgets(12),
        reason: 'all 12 fetched wallpapers must render');
    expect(find.byKey(const ValueKey('mixed_feed_ad_slot_0')), findsNothing,
        reason: 'Category Details must never insert a per-6 ad slot into '
            'the grid - that policy stays exclusive to Explore/Home');
  });

  testWidgets(
      'shows exactly one persistent AdaptiveBannerAd, anchored below the '
      'grid rather than inside its scrollable content', (tester) async {
    await pumpPage(
      tester,
      _FakeGetCategoryWallpapersUseCase(
        Paginated(items: twelveWallpapers, page: 1, hasMore: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveBannerAd), findsOneWidget,
        reason: 'exactly one persistent banner for the whole screen - '
            'never zero, never duplicated across rebuilds/pagination');

    // The banner must sit below the grid's CustomScrollView, not as one of
    // its slivers - i.e. it is a sibling in the outer Column, not something
    // that scrolls away with the wallpaper list.
    final bannerY = tester.getTopLeft(find.byType(AdaptiveBannerAd)).dy;
    final gridBottom =
        tester.getBottomRight(find.byType(CustomScrollView)).dy;
    expect(bannerY, greaterThanOrEqualTo(gridBottom - 1),
        reason: 'the banner must be anchored below the grid area, not '
            'layered inside/over it');
  });

  testWidgets(
      'with 9 wallpapers the grid is ONE continuous run of cells - no '
      'synthetic ad/placeholder entry, and no ad-sized vertical gap after '
      'wallpaper #6', (tester) async {
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nine = List.generate(9, (i) => wallpaper('n$i'));
    await pumpPage(
      tester,
      _FakeGetCategoryWallpapersUseCase(
        Paginated(items: nine, page: 1, hasMore: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperCard), findsNWidgets(9));

    // Row pitch must be identical for every row: the old grouped-by-6
    // structure re-applied the grid's vertical padding per group, opening a
    // ~128px band between wallpaper #6 and #7 that no other row had.
    double topOf(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('wallpaper_$id'))).dy;
    final rowTops = [topOf('n0'), topOf('n2'), topOf('n4'), topOf('n6'), topOf('n8')];
    final pitches = [
      for (var i = 1; i < rowTops.length; i++) rowTops[i] - rowTops[i - 1],
    ];
    for (final pitch in pitches) {
      expect(pitch, closeTo(pitches.first, 1),
          reason: 'every row must be the same distance apart - a larger gap '
              'anywhere is a leftover reserved ad slot. Pitches: $pitches');
    }
  });

  for (final count in [1, 5, 6, 7, 12]) {
    testWidgets(
        'with $count wallpapers every cell is a real wallpaper - no count '
        'produces a reserved ad-sized region', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = List.generate(count, (i) => wallpaper('c$i'));
      await pumpPage(
        tester,
        _FakeGetCategoryWallpapersUseCase(
          Paginated(items: items, page: 1, hasMore: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WallpaperCard), findsNWidgets(count));
      expect(find.byKey(const ValueKey('mixed_feed_ad_slot_0')), findsNothing);
      // The single persistent banner is a sibling below the grid, never an
      // entry inside it - so it exists exactly once at every count.
      expect(find.byType(AdaptiveBannerAd), findsOneWidget);
    });
  }

  testWidgets(
      'while loading, shows CategoryGridShimmer whose placeholder cells '
      'match kWallpaperCardAspectRatio - the exact geometry the real grid '
      'uses, so real content replacing it causes no layout shift',
      (tester) async {
    await pumpPage(
      tester,
      _FakeGetCategoryWallpapersUseCase(null, neverResolve: true),
    );
    await tester.pump();

    expect(find.byType(CategoryGridShimmer), findsOneWidget);

    final cellFinder = find.descendant(
      of: find.byType(CategoryGridShimmer),
      matching: find.byType(LoadingShimmer),
    );
    expect(cellFinder, findsWidgets);
    final size = tester.getSize(cellFinder.first);
    expect(size.width / size.height, closeTo(kWallpaperCardAspectRatio, 0.01),
        reason: 'shimmer cells must use the same aspect ratio as real '
            'WallpaperCard cells');
  });
}

class _FakeGetCategoryWallpapersUseCase
    implements GetCategoryWallpapersUseCase {
  _FakeGetCategoryWallpapersUseCase(this._page, {this.neverResolve = false});

  final Paginated<WallpaperEntity>? _page;
  final bool neverResolve;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
    CategoryWallpapersParams params,
  ) {
    if (neverResolve) {
      return Completer<Either<Failure, Paginated<WallpaperEntity>>>().future;
    }
    return Future.value(Right(_page ?? const Paginated.empty()));
  }
}

/// Never invoked by these tests (they only open REAL category slugs), but
/// CategoryDetailsBloc now requires it for the "Live Wallpapers"
/// pseudo-category - see LiveCategory.
class _UnusedGetLiveWallpapersUseCase implements GetLiveWallpapersUseCase {
  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
    PageParams params,
  ) async =>
      const Right(Paginated.empty());
}
