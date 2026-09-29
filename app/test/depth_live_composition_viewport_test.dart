import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/depth/presentation/widgets/depth_live_composition.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:creativebackground/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:creativebackground/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/domain/repositories/wallpaper_details_repository.dart';
import 'package:creativebackground/features/wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/bloc/wallpaper_details_bloc.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/pages/wallpaper_details_page.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the viewport/coordinate handling of live DEPTH Details against the
/// physical-device-verified contract: DEPTH Details must show the SAME
/// COVER geometry the native applied wallpaper uses
/// (`DepthCompositor.drawCoverBitmap`), not a letterboxed, aspect-locked box.
///
/// An earlier revision of this suite asserted the OPPOSITE - that Details
/// must aspect-lock to the wallpaper's own `width`/`height` and letterbox
/// any mismatch - which was the correct fix for a DIFFERENT, now-superseded
/// bug (an `AspectRatio` stretching to fill tight constraints entirely,
/// losing its own ratio). That aspect-lock has since been proven to
/// reproduce the reported "black/empty top gap" on a physical device
/// whenever the wallpaper's source ratio didn't match the screen's -
/// exactly the class of bug `wallpaper_top_gap_coverage_test.dart` fixed for
/// the native renderers. This suite now asserts the composition fills its
/// given box edge-to-edge instead of aspect-locking within it.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  void mockChannels(WallpaperEntity wallpaper) {
    di.sl.registerFactory<WallpaperDetailsBloc>(
      () => WallpaperDetailsBloc(
        getDetails: GetWallpaperDetailsUseCase(
          _FakeDetailsRepository(wallpaper),
        ),
        addFavorite: AddFavoriteUseCase(_FakeFavoritesRepository()),
        removeFavorite: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
        favoritesRepository: _FakeFavoritesRepository(),
        repository: _FakeDetailsRepository(wallpaper),
      ),
    );
  }

  tearDown(() => di.sl.reset());

  testWidgets(
    'a depth wallpaper whose aspect ratio does NOT match the device screen '
    'still fills the FULL Details viewport - no aspect-locked letterbox gap',
    (tester) async {
      // Bunny's real production ratio: 941x1672 (0.5628), deliberately
      // pumped against a wider/taller test surface (matches
      // `wallpaper_details_no_destructive_crop_test.dart`'s own approach of
      // picking a ratio that would visibly differ under `.cover`).
      final wallpaper = WallpaperEntity(
        id: 'w1',
        title: 'Depth aspect test',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/composite.webp',
        backgroundUrl: 'https://cdn.test/bg.webp',
        foregroundMaskUrl: 'https://cdn.test/fg.webp',
        hasForegroundMask: true,
        resolution: '941x1672',
        width: 941,
        height: 1672,
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 80),
        ),
      );
      mockChannels(wallpaper);

      const screenSize = Size(1080, 2424);
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(id: 'w1', knownWallpaper: wallpaper),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // No AspectRatio box locks the composite to the wallpaper's own
      // 941x1672 ratio any more - that box is exactly what left the
      // letterboxed gap the physical device reproduced.
      expect(
        find.byWidgetPredicate(
          (w) => w is AspectRatio && (w.aspectRatio - 941 / 1672).abs() < 1e-6,
        ),
        findsNothing,
        reason: 'the depth composite must no longer be aspect-locked to the '
            'wallpaper\'s own ratio inside Details - that is the box that '
            'produced the reported top gap',
      );

      // The composition fills the full screen-sized Details viewport
      // instead.
      final renderedSize = tester.getSize(
        find.byType(DepthLiveComposition),
      );
      expect(renderedSize.width, closeTo(screenSize.width, 1));
      expect(renderedSize.height, closeTo(screenSize.height, 1));
    },
  );

  testWidgets(
    'the clock still renders inside DepthLiveComposition\'s own full-screen '
    'box, so customX/customY anchor against the same viewport the native '
    'applied wallpaper uses',
    (tester) async {
      final wallpaper = WallpaperEntity(
        id: 'w2',
        title: 'Depth anchor test',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/composite.webp',
        backgroundUrl: 'https://cdn.test/bg.webp',
        foregroundMaskUrl: 'https://cdn.test/fg.webp',
        hasForegroundMask: true,
        resolution: '941x1672',
        width: 941,
        height: 1672,
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(
            enabled: true,
            sizePx: 80,
            customX: 0.5,
            customY: 0.5,
          ),
        ),
      );
      mockChannels(wallpaper);

      const screenSize = Size(1080, 2424);
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(id: 'w2', knownWallpaper: wallpaper),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final clockFinder = find.byType(ClockRendererWidget);
      expect(clockFinder, findsOneWidget);

      final clockAncestorSize = tester.getSize(
        find
            .ancestor(
              of: clockFinder,
              matching: find.byType(DepthLiveComposition),
            )
            .first,
      );
      expect(clockAncestorSize.width, closeTo(screenSize.width, 1));
      expect(clockAncestorSize.height, closeTo(screenSize.height, 1));
    },
  );
}

class _FakeDetailsRepository implements WallpaperDetailsRepository {
  _FakeDetailsRepository(this.wallpaper);
  final WallpaperEntity wallpaper;

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(
    String idOrSlug,
  ) async =>
      Right(wallpaper);

  @override
  Future<void> recordView(String idOrSlug) async {}
}

class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Future<Either<Failure, List<WallpaperEntity>>> getFavorites() async =>
      const Right([]);

  @override
  Future<Either<Failure, Unit>> addFavorite(WallpaperEntity wallpaper) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> removeFavorite(String wallpaperId) async =>
      const Right(unit);

  @override
  bool isFavorite(String wallpaperId) => false;

  @override
  Stream<void> watchChanges() => const Stream.empty();
}
