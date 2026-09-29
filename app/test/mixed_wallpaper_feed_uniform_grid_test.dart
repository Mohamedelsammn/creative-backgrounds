import 'package:creativebackground/core/widgets/mixed_wallpaper_feed_sliver.dart';
import 'package:creativebackground/core/widgets/wallpaper_card.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Home/Category-Details wallpaper feed must be a STRICT uniform
/// 2-column grid - every card exactly the same size - never a masonry/
/// staggered layout where card height varies by position or source aspect
/// ratio. This is the exact regression the redesign's masonry
/// (`SliverMasonryGrid.count` + a cycling `[0.72, 0.9, 0.82, 0.68]` aspect
/// ratio list) introduced and this correction pass removes.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(String id, {int width = 0, int height = 0}) =>
      WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
        width: width,
        height: height,
      );

  Future<void> pumpGrid(
    WidgetTester tester,
    List<WallpaperEntity> wallpapers,
  ) async {
    // Tall enough that every row actually lays out at the current (taller,
    // 9:16) kWallpaperCardAspectRatio - the default test viewport is too
    // short to fit more than one row of 9:16 cards, which would make
    // "every card" assertions below vacuous for anything past the first row.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: buildMixedWallpaperFeedSlivers(
                context,
                wallpapers: wallpapers,
                hasMore: false,
                isLoadingMore: false,
                onTap: (w, h) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'every wallpaper card in the grid has the exact same width and '
      'height, regardless of each wallpaper\'s own source aspect ratio',
      (tester) async {
    // Deliberately varied source dimensions - a masonry layout derives card
    // height from these; a uniform grid must ignore them entirely.
    final wallpapers = [
      wallpaper('a', width: 1080, height: 1920), // tall
      wallpaper('b', width: 1080, height: 1080), // square
      wallpaper('c', width: 1920, height: 1080), // wide
      wallpaper('d', width: 1080, height: 2400), // very tall
    ];
    await pumpGrid(tester, wallpapers);

    final sizes = tester
        .widgetList<WallpaperCard>(find.byType(WallpaperCard))
        .map((card) => tester.getSize(find.byWidget(card)))
        .toList();

    expect(sizes, hasLength(4));
    final first = sizes.first;
    for (final size in sizes) {
      expect(size.width, closeTo(first.width, 0.5),
          reason: 'every card must share the same width');
      expect(size.height, closeTo(first.height, 0.5),
          reason: 'every card must share the same height - a masonry/'
              'staggered layout would vary this by source aspect ratio');
    }
  });

  testWidgets('the grid uses kWallpaperCardAspectRatio for every cell',
      (tester) async {
    final wallpapers = List.generate(6, (i) => wallpaper('w$i'));
    await pumpGrid(tester, wallpapers);

    final size = tester.getSize(find.byType(WallpaperCard).first);
    expect(size.width / size.height, closeTo(kWallpaperCardAspectRatio, 0.01));
  });
}
