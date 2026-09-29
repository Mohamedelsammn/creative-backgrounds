import 'package:creativebackground/core/widgets/mixed_wallpaper_feed_sliver.dart';
import 'package:creativebackground/core/widgets/wallpaper_card.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the reported "Home scroll jumps backward"
/// bug.
///
/// ROOT CAUSE (confirmed by reading `adaptive_banner_ad.dart` and
/// `adaptive_banner_manager.dart`): `AdaptiveBannerAd` reserved
/// `AdSize.banner.height` (a hardcoded 50) as its ad slot's height until
/// `AdaptiveBannerManager.load()`'s async `AdSize
/// .getCurrentOrientationAnchoredAdaptiveBannerAdSize` call resolved the
/// REAL adaptive height (device-dependent, typically 50-90dp) a frame or
/// two later. Every new ad slot - created exactly when pagination crossed a
/// 6-wallpaper boundary - grew taller AFTER already being laid out,
/// pushing every sliver below it down by the height delta. Scrolled content
/// sliding down while `pixels` stays fixed is indistinguishable from "the
/// feed jumped backward" to the user. Fixed by caching the resolved
/// adaptive height across the whole session (`_cachedHeightByWidth` in
/// `AdaptiveBannerManager`) so every slot after the very first reserves the
/// REAL height from its first frame, never a placeholder that changes.
///
/// This test covers the OTHER structural half of the same bug class: that
/// growing the wallpaper list itself (independent of ads) never moves an
/// already-rendered card. `buildMixedWallpaperFeedSlivers` keys every grid
/// group (`grid_group_N`) and every wallpaper card (`wallpaper_<id>`) by
/// stable identity rather than list position, so a later page's items are a
/// pure append - no earlier sliver's widget identity changes.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(String id) => WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
      );

  Widget buildFeed(List<WallpaperEntity> wallpapers) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => CustomScrollView(
            slivers: buildMixedWallpaperFeedSlivers(
              context,
              wallpapers: wallpapers,
              hasMore: true,
              isLoadingMore: false,
              onTap: (w, h) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'appending a second page of wallpapers (crossing a 6-item ad-slot '
      'boundary) does not move any already-rendered card - a pure append, '
      'never a mid-list structural change', (tester) async {
    // Tall enough that all 12 first-page cards are actually laid out
    // (Flutter otherwise lazily skips slivers below the tiny default test
    // viewport, which would make this assertion vacuous).
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Page 1: exactly 12 items - two full groups of 6, so the SECOND
    // group's ad slot does not exist yet (`groupEnd(12) < length(12)` is
    // false). This is the exact shape that changes when page 2 arrives.
    final page1 = List.generate(12, (i) => wallpaper('w$i'));
    await tester.pumpWidget(buildFeed(page1));
    await tester.pump();

    final firstCardBefore =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w0')));
    final lastCardBefore =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w11')));

    // Page 2 arrives: 18 items total. A new ad slot now appears after the
    // second group (`12 < 18` is true) - the exact structural change the
    // bug report described as "reaching the next wallpaper batch".
    final page2 = [...page1, ...List.generate(6, (i) => wallpaper('x$i'))];
    await tester.pumpWidget(buildFeed(page2));
    await tester.pump();

    final firstCardAfter =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w0')));
    final lastCardAfter =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w11')));

    expect(firstCardAfter, firstCardBefore,
        reason: 'the very first card must not move when a later page '
            'arrives');
    expect(lastCardAfter, lastCardBefore,
        reason: 'the last card of the previously-loaded page must not '
            'move either, even though a new ad slot is inserted '
            'immediately after it');
  });

  testWidgets(
      'every wallpaper card keeps a stable key across repeated pagination '
      '(3 pages), so Flutter never confuses one card for another by '
      'position', (tester) async {
    // Tall enough to lay out all 9 rows (18 items / 2 columns) at the
    // current (taller, 9:16) kWallpaperCardAspectRatio - this test's final
    // assertion requires every card actually built, not just found lazily.
    tester.view.physicalSize = const Size(1080, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var wallpapers = List.generate(6, (i) => wallpaper('p1_$i'));
    await tester.pumpWidget(buildFeed(wallpapers));
    await tester.pump();

    for (final page in [2, 3]) {
      wallpapers = [
        ...wallpapers,
        ...List.generate(6, (i) => wallpaper('p${page}_$i')),
      ];
      await tester.pumpWidget(buildFeed(wallpapers));
      await tester.pump();

      for (final w in wallpapers) {
        expect(
          find.byKey(ValueKey('wallpaper_${w.id}')),
          findsOneWidget,
          reason: 'wallpaper ${w.id} must still be found by its own '
              'stable key after page $page loads',
        );
      }
    }

    expect(find.byType(WallpaperCard), findsNWidgets(18));
  });
}
