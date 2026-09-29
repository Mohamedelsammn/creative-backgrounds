import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
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

/// Section 9's audit: does Details ever paint a STALE asset after the
/// dashboard re-bakes a wallpaper's `STYLED_PREVIEW`?
///
/// The backend's own contract makes this safe BY CONSTRUCTION: a re-bake
/// (`POST /admin/wallpapers/{id}/studio/render`) always produces a new,
/// content-hashed URL - see `AssetKind.styledPreview`'s doc - so a stale
/// cache entry keyed by the OLD url is simply never looked up again; there
/// is no url to invalidate, only a new one to key by. This test locks in the
/// Flutter-side half of that: the widget identity Details paints under is
/// derived from `resolveDetailsVisual().imageUrl`, not just the wallpaper's
/// id, so a re-bake between the list's "known" wallpaper and the detail
/// response's freshly-fetched one forces a real rebuild/reload rather than
/// silently keeping the old picture on screen under a stale State object.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  const oldStyledUrl = 'https://cdn.test/w1/styled-preview-v1-aaaa.webp';
  const newStyledUrl = 'https://cdn.test/w1/styled-preview-v2-bbbb.webp';

  const clock = ClockConfigEntity(enabled: true, sizePx: 80);

  WallpaperEntity wallpaperWith(String styledPreviewUrl) => WallpaperEntity(
        id: 'w1',
        title: 'Re-baked wallpaper',
        category: category,
        thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
        fullUrl: 'https://cdn.test/w1-full.webp',
        resolution: '1080x1920',
        width: 1080,
        height: 1920,
        isDetailed: true,
        design: StudioDesign(
          clock: clock,
          styledPreviewUrl: styledPreviewUrl,
        ),
      );

  final knownWallpaper = wallpaperWith(oldStyledUrl);
  final freshWallpaper = wallpaperWith(newStyledUrl);

  setUp(() {
    di.sl.registerFactory<WallpaperDetailsBloc>(
      () => WallpaperDetailsBloc(
        getDetails:
            GetWallpaperDetailsUseCase(_FakeDetailsRepository(freshWallpaper)),
        addFavorite: AddFavoriteUseCase(_FakeFavoritesRepository()),
        removeFavorite: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
        favoritesRepository: _FakeFavoritesRepository(),
        repository: _FakeDetailsRepository(freshWallpaper),
      ),
    );
  });

  tearDown(() => di.sl.reset());

  test(
    'resolveDetailsVisual resolves to the freshly re-baked url, not the '
    'stale one the list still remembers',
    () {
      expect(knownWallpaper.resolveDetailsVisual().imageUrl, oldStyledUrl);
      expect(freshWallpaper.resolveDetailsVisual().imageUrl, newStyledUrl);
    },
  );

  testWidgets(
    'once the detail response lands with a re-baked STYLED_PREVIEW, the '
    'OLD styled url is no longer painted anywhere on Details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(
            id: 'w1',
            // The list's own stale copy - what the user tapped from,
            // authored with the OLD styled-preview url.
            knownWallpaper: knownWallpaper,
          ),
        ),
      );
      // First frame: the known (stale) wallpaper paints immediately.
      await tester.pump();

      // The bloc's async `getWallpaperDetails` call resolves, delivering
      // the fresh wallpaper with the NEW styled-preview url.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final images = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(images, isNotEmpty);
      for (final image in images) {
        expect(
          image.imageUrl,
          isNot(oldStyledUrl),
          reason: 'the stale pre-rebake asset must never remain on screen '
              'once the fresh detail response has arrived',
        );
      }
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
