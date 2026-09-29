import 'package:creativebackground/core/widgets/live_wallpaper_player.dart';
import 'package:creativebackground/core/widgets/media_player_preview.dart';
import 'package:creativebackground/core/widgets/mixed_wallpaper_feed_sliver.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/features/explore/domain/repositories/explore_repository.dart';
import 'package:creativebackground/features/explore/domain/usecases/resolve_video_url_usecase.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Verifies the pre-existing app-wide "at most 1 live decoder" policy
/// (`_ActiveVideoRegistry` inside `live_wallpaper_player.dart`) still holds
/// once Home's cards grew taller (`kWallpaperCardAspectRatio` 0.72 -> 9/16).
/// That registry is driven purely by `VisibilityDetector.visibleFraction`,
/// with no dependency on a card's actual pixel size - this test exercises
/// it through the REAL grid (`buildMixedWallpaperFeedSlivers` +
/// `WallpaperCard`) at the new, taller ratio rather than a synthetic
/// fixed-height host, to confirm the taller cards don't change visibility
/// detection or the cap in practice.
void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  setUp(() {
    LiveWallpaperPlayer.videoPlayerKnownBroken = true;
    // Every test wallpaper already carries its own `video` asset, so
    // ResolveVideoUrlUseCase.call() returns it synchronously without ever
    // reaching this repository - it only needs to exist to satisfy DI.
    di.sl.registerLazySingleton<ResolveVideoUrlUseCase>(
      () => ResolveVideoUrlUseCase(_UnusedExploreRepository()),
    );
  });
  tearDown(() {
    LiveWallpaperPlayer.videoPlayerKnownBroken = false;
    di.sl.reset();
  });

  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(String id, {WallpaperType type = WallpaperType.normal}) =>
      WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        type: type,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
        // A video already present on the entity lets ResolveVideoUrlUseCase
        // return it synchronously with zero repository/DI call - the exact
        // "backend included it directly on the feed row" fast path it
        // documents, which is all this test needs to exercise the player.
        video: type == WallpaperType.live
            ? VideoAsset(
                url: 'https://cdn.test/$id.mp4',
                mime: 'video/mp4',
                width: 1080,
                height: 1920,
                durationMs: 3000,
                fps: 30,
                sizeBytes: 1000,
                codec: 'h264',
              )
            : null,
      );

  Future<void> pumpFeed(
    WidgetTester tester,
    List<WallpaperEntity> wallpapers,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
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

  Future<void> setVisibility(
    WidgetTester tester,
    Key detectorKey,
    double fraction,
  ) async {
    final detector =
        tester.widget<VisibilityDetector>(find.byKey(detectorKey));
    const size = Size(100, 100);
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detectorKey,
        size: size,
        visibleBounds: Rect.fromLTWH(0, 0, size.width, size.height * fraction),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'LIVE, NORMAL, LIVE sequence in the taller grid: at most one live '
      'card ever holds a decoder, and the normal (static) card in between '
      'is unaffected', (tester) async {
    final wallpapers = [
      wallpaper('live-a', type: WallpaperType.live),
      wallpaper('normal-b'),
      wallpaper('live-c', type: WallpaperType.live),
    ];
    await pumpFeed(tester, wallpapers);

    // Confirm the new taller ratio is actually what's laid out here.
    final size = tester.getSize(find.byKey(const ValueKey('wallpaper_live-a')));
    expect(size.width / size.height, closeTo(kWallpaperCardAspectRatio, 0.01));

    final keyLiveA = const Key('live_player_https://cdn.test/live-a.webp');
    final keyLiveC = const Key('live_player_https://cdn.test/live-c.webp');

    await setVisibility(tester, keyLiveA, 1.0);
    await setVisibility(tester, keyLiveC, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MediaPlayerPreview), findsOneWidget,
        reason: 'only one of the two LIVE cards may hold the single '
            'app-wide decoder slot at once, even at the taller card ratio');
  });

  testWidgets(
      'LIVE, LIVE sequence (adjacent) in the taller grid: still exactly '
      'one decoder active when both become visible simultaneously',
      (tester) async {
    final wallpapers = [
      wallpaper('live-x', type: WallpaperType.live),
      wallpaper('live-y', type: WallpaperType.live),
    ];
    await pumpFeed(tester, wallpapers);

    final keyLiveX = const Key('live_player_https://cdn.test/live-x.webp');
    final keyLiveY = const Key('live_player_https://cdn.test/live-y.webp');

    await setVisibility(tester, keyLiveX, 1.0);
    await setVisibility(tester, keyLiveY, 1.0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MediaPlayerPreview), findsOneWidget,
        reason: 'adjacent LIVE/LIVE cards at the taller ratio must still '
            'obey the app-wide single-decoder cap');
  });
}

/// Never actually invoked - every test wallpaper already carries its own
/// `video` asset, so `ResolveVideoUrlUseCase.call()` returns it synchronously
/// without reaching this repository. It only needs to exist to satisfy DI.
class _UnusedExploreRepository implements ExploreRepository {
  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({
    String? cursor,
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLiveWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getDepthWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getNewWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    bool forceRefresh = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, String?>> getWallpaperVideoUrl(String idOrSlug) =>
      throw UnimplementedError();
}
