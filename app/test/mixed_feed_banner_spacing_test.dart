import 'package:creativebackground/core/ads/adaptive_banner_manager.dart';
import 'package:creativebackground/core/theme/app_spacing.dart';
import 'package:creativebackground/core/widgets/adaptive_banner_ad.dart';
import 'package:creativebackground/core/widgets/mixed_wallpaper_feed_sliver.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the Home feed's banner spacing.
///
/// The ad slot between wallpaper groups reserved `AppSpacing.section` above
/// the banner but NOTHING below it, so the row directly after the banner sat
/// flush against it while the row above enjoyed a normal, intentional gap -
/// an unbalanced band that read as a layout bug rather than a deliberate
/// section break.
///
/// This only exercises layout: `AdaptiveBannerManager.load()` is called by
/// `AdaptiveBannerAd` but never awaited by this test (matching
/// `explore_scroll_stability_test.dart`'s and
/// `category_details_ads_and_shimmer_test.dart`'s established pattern of a
/// single `pump()`, never `pumpAndSettle()`) - the banner's own box always
/// reserves a fixed placeholder height regardless of whether the real ad
/// ever loads (see `AdaptiveBannerAd`'s own doc), so the padding around it is
/// measurable without a real network round trip.
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

  // 12 wallpapers = two full groups of 6, so exactly one ad slot (after
  // group 0, before group 1) exists - "wallpapers 1-6, banner, wallpapers
  // 7-12", the exact shape asked for.
  final twelveWallpapers = List.generate(12, (i) => wallpaper('w$i'));

  Future<void> pumpFeed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final managers = <int, AdaptiveBannerManager>{};
    addTearDown(() {
      for (final m in managers.values) {
        m.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: buildMixedWallpaperFeedSlivers(
                context,
                wallpapers: twelveWallpapers,
                hasMore: false,
                isLoadingMore: false,
                onTap: (w, h) {},
                adUnitId: 'test-ad-unit',
                bannerManagerAt: (slot, adUnitId) =>
                    managers.putIfAbsent(slot, () => AdaptiveBannerManager(adUnitId)),
              ),
            ),
          ),
        ),
      ),
    );
    // A single pump, never pumpAndSettle - `AdaptiveBannerAd.build` fires an
    // unawaited `manager.load(...)` that hits a real (unmocked) platform
    // channel in a test; settling would hang/error waiting on it. The
    // placeholder box the banner reserves is already correctly sized after
    // one frame, which is all this layout test needs.
    await tester.pump();
  }

  testWidgets(
      'the ad slot reserves an EQUAL gap above and below the banner - '
      'wallpapers 1-6, banner, wallpapers 7-12', (tester) async {
    await pumpFeed(tester);

    expect(find.byKey(const ValueKey('mixed_feed_ad_slot_0')), findsOneWidget);

    // `mixed_feed_ad_slot_0` is the key on the SliverToBoxAdapter, a sliver
    // rather than a RenderBox, so its geometry is read through the
    // AdaptiveBannerAd it contains instead - the one RenderBox-backed widget
    // inside that slot.
    final bannerBox = find.byType(AdaptiveBannerAd);
    expect(bannerBox, findsOneWidget);

    // Bottom edge of the last card in the first group (w5, the 6th item,
    // 0-indexed) and top edge of the banner's own box.
    final group0BottomCardBottom =
        tester.getBottomLeft(find.byKey(const ValueKey('wallpaper_w5'))).dy;
    final adSlotTop = tester.getTopLeft(bannerBox).dy;
    final gapAbove = adSlotTop - group0BottomCardBottom;

    // Bottom edge of the banner's own box and top edge of the first card in
    // the second group (w6, the 7th item).
    final adSlotBottom = tester.getBottomLeft(bannerBox).dy;
    final group1TopCardTop =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w6'))).dy;
    final gapBelow = group1TopCardTop - adSlotBottom;

    expect(
      gapBelow,
      closeTo(gapAbove, 1),
      reason: 'the gap below the banner must match the gap above it - '
          'previously it was zero',
    );
    expect(
      gapBelow,
      greaterThan(0),
      reason: 'wallpapers 7-12 must not sit flush against the banner',
    );
  });

  testWidgets(
      'both the above-banner and below-banner gaps equal AppSpacing.section',
      (tester) async {
    await pumpFeed(tester);

    final bannerBox = find.byType(AdaptiveBannerAd);
    final group0BottomCardBottom =
        tester.getBottomLeft(find.byKey(const ValueKey('wallpaper_w5'))).dy;
    final adSlotTop = tester.getTopLeft(bannerBox).dy;
    final adSlotBottom = tester.getBottomLeft(bannerBox).dy;
    final group1TopCardTop =
        tester.getTopLeft(find.byKey(const ValueKey('wallpaper_w6'))).dy;

    expect(
      adSlotTop - group0BottomCardBottom,
      closeTo(AppSpacing.section, 1),
    );
    expect(
      group1TopCardTop - adSlotBottom,
      closeTo(AppSpacing.section, 1),
    );
  });

  testWidgets('no ad slot is inserted after a trailing partial group',
      (tester) async {
    // 8 wallpapers: group 0 is a FULL group of 6 (items 0-5), so it DOES get
    // an ad slot (slot 0) - the interesting case is group 1, a PARTIAL group
    // of 2 (items 6-7), which must NOT get a trailing ad slot (slot 1).
    final eight = List.generate(8, (i) => wallpaper('w$i'));
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final managers = <int, AdaptiveBannerManager>{};
    addTearDown(() {
      for (final m in managers.values) {
        m.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: buildMixedWallpaperFeedSlivers(
                context,
                wallpapers: eight,
                hasMore: false,
                isLoadingMore: false,
                onTap: (w, h) {},
                adUnitId: 'test-ad-unit',
                bannerManagerAt: (slot, adUnitId) =>
                    managers.putIfAbsent(slot, () => AdaptiveBannerManager(adUnitId)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mixed_feed_ad_slot_0')),
      findsOneWidget,
      reason: 'group 0 is a full 6-item group, so it DOES get an ad slot',
    );
    expect(
      find.byKey(const ValueKey('mixed_feed_ad_slot_1')),
      findsNothing,
      reason: 'group 1 is a partial 2-item trailing group - no ad follows it',
    );
  });
}
