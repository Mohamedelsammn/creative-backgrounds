import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
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

/// History: an earlier bug report ("static wallpaper is cropped left/right
/// on Details") was fixed by switching `_TwoStageWallpaperImage` from
/// `BoxFit.cover` to `.contain`, trading crop for letterboxing. A LATER,
/// physical-device-verified bug report showed that trade the wrong way
/// round: `.contain`'s letterbox margin is exactly what produced a reported
/// black/empty gap at the top of Details for a wallpaper whose aspect ratio
/// didn't match the screen's - and the native applied-wallpaper path (proven
/// correct on a physical OPPO device for "With Design") already uses COVER,
/// not FIT. Details switched back to `.cover` so it shows the SAME
/// composition the wallpaper will actually have once applied, rather than a
/// third, letterboxed rendering only Details ever showed. This test now
/// asserts `.cover`, the current, physical-device-confirmed contract.
///
/// This is purely a Flutter *rendering* concern - it has zero effect on the
/// bytes Apply reads (Apply downloads/decodes the original file directly,
/// never a screenshot of this widget) - see `wallpaper_top_gap_coverage_test
/// .dart` for the native-side COVER fix this mirrors.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  final wallpaper = WallpaperEntity(
    id: 'w1',
    title: 'Wide composition',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
    fullUrl: 'https://cdn.test/w1-full.webp',
    // Deliberately a ratio that does NOT match a typical phone screen, so a
    // `.cover` fit would visibly crop it - the exact condition the bug
    // report described.
    resolution: '2160x3840',
    width: 2160,
    height: 3840,
    isDetailed: true,
  );

  setUp(() {
    di.sl.registerFactory<WallpaperDetailsBloc>(
      () => WallpaperDetailsBloc(
        getDetails: GetWallpaperDetailsUseCase(_FakeDetailsRepository(wallpaper)),
        addFavorite: AddFavoriteUseCase(_FakeFavoritesRepository()),
        removeFavorite: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
        favoritesRepository: _FakeFavoritesRepository(),
        repository: _FakeDetailsRepository(wallpaper),
      ),
    );
  });

  tearDown(() => di.sl.reset());

  testWidgets(
      'Details renders the wallpaper image with BoxFit.cover, matching the '
      'native applied wallpaper\'s own geometry - no letterbox gap',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WallpaperDetailsPage(id: 'w1', knownWallpaper: wallpaper),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final images = tester.widgetList<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(images, isNotEmpty,
        reason: 'Details must render at least one CachedNetworkImage for '
            'the wallpaper itself');
    for (final image in images) {
      expect(image.fit, BoxFit.cover,
          reason: 'every wallpaper image layer on Details must use .cover, '
              'matching the native COVER geometry confirmed correct on a '
              'physical device - .contain is what produced the reported '
              'top-gap bug');
    }
  });
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
