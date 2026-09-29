import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:creativebackground/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:creativebackground/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/domain/repositories/wallpaper_details_repository.dart';
import 'package:creativebackground/features/wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/bloc/wallpaper_details_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reported bug: opening Details always showed a loading spinner, even
/// though the tapped list row already has everything needed to paint the
/// screen (thumbnail, title, category). `WallpaperDetailsFetchRequested` now
/// carries that already-known entity so the bloc can show it immediately,
/// then silently upgrade to the full detail once the network round-trip
/// completes.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  final knownWallpaper = WallpaperEntity(
    id: 'w1',
    title: 'Known wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
    fullUrl: 'https://cdn.test/w1-thumb.webp',
    resolution: '1080x1920',
  );

  final fullDetail = WallpaperEntity(
    id: 'w1',
    title: 'Known wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
    fullUrl: 'https://cdn.test/w1-full.webp',
    description: 'The full detail, only available after the network call.',
    resolution: '1080x1920',
    isDetailed: true,
  );

  WallpaperDetailsBloc bloc({
    required Either<Failure, WallpaperEntity> result,
  }) {
    return WallpaperDetailsBloc(
      getDetails: GetWallpaperDetailsUseCase(_FakeDetailsRepository(result)),
      addFavorite: AddFavoriteUseCase(_FakeFavoritesRepository()),
      removeFavorite: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
      favoritesRepository: _FakeFavoritesRepository(),
      repository: _FakeDetailsRepository(result),
    );
  }

  test('with a known wallpaper, the FIRST emitted state is already Loaded - '
      'never a bare loading spinner', () async {
    final b = bloc(result: Right(fullDetail));
    final states = <WallpaperDetailsState>[];
    final sub = b.stream.listen(states.add);

    b.add(WallpaperDetailsFetchRequested('w1', knownWallpaper: knownWallpaper));
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<WallpaperDetailsLoaded>());
    expect(
      (states.first as WallpaperDetailsLoaded).wallpaper.fullUrl,
      knownWallpaper.fullUrl,
      reason: 'the very first paint must use the already-known data',
    );

    await sub.cancel();
    await b.close();
  });

  test('the known wallpaper is silently upgraded to the full detail once the '
      'network call completes', () async {
    final b = bloc(result: Right(fullDetail));
    b.add(WallpaperDetailsFetchRequested('w1', knownWallpaper: knownWallpaper));

    final finalState =
        await b.stream.firstWhere(
              (s) => s is WallpaperDetailsLoaded && s.wallpaper.isDetailed,
            )
            as WallpaperDetailsLoaded;

    expect(finalState.wallpaper.fullUrl, fullDetail.fullUrl);
    expect(finalState.wallpaper.description, isNotNull);
    await b.close();
  });

  test('with NO known wallpaper (e.g. a deep link), the bloc falls back to '
      'the loading state exactly as before', () async {
    final b = bloc(result: Right(fullDetail));
    final states = <WallpaperDetailsState>[];
    final sub = b.stream.listen(states.add);

    b.add(const WallpaperDetailsFetchRequested('w1'));
    await Future<void>.delayed(Duration.zero);

    expect(states.first, isA<WallpaperDetailsLoading>());

    await sub.cancel();
    await b.close();
  });

  test('if the network refresh fails but a known wallpaper is already shown, '
      'the screen stays on the known wallpaper rather than blanking to an '
      'error', () async {
    final b = bloc(result: const Left(NetworkTimeoutFailure()));
    b.add(WallpaperDetailsFetchRequested('w1', knownWallpaper: knownWallpaper));

    // Give the failed fetch a chance to resolve and (not) emit an error.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(b.state, isA<WallpaperDetailsLoaded>());
    expect((b.state as WallpaperDetailsLoaded).wallpaper.id, 'w1');
    await b.close();
  });

  test('with no known wallpaper, a failed fetch still surfaces the error '
      'state as before', () async {
    final b = bloc(result: const Left(NetworkTimeoutFailure()));
    b.add(const WallpaperDetailsFetchRequested('w1'));

    final state = await b.stream.firstWhere((s) => s is WallpaperDetailsError);
    expect(state, isA<WallpaperDetailsError>());
    await b.close();
  });

  test(
    'Details prefers PREVIEW while fullUrl remains the original apply asset',
    () {
      final wallpaper = fullDetail.copyWith(
        assets: const {
          AssetKind.preview: RemoteAsset(
            url: 'https://cdn.test/w1-preview.webp',
            mime: 'image/webp',
            width: 1080,
            height: 2340,
          ),
          AssetKind.original: RemoteAsset(
            url: 'https://cdn.test/w1-original.webp',
            mime: 'image/webp',
            width: 4000,
            height: 8667,
          ),
        },
        fullUrl: 'https://cdn.test/w1-original.webp',
      );

      expect(wallpaper.detailsPreviewUrl, 'https://cdn.test/w1-preview.webp');
      expect(wallpaper.detailsPreviewWidth, 1080);
      expect(wallpaper.detailsPreviewHeight, 2340);
      expect(wallpaper.fullUrl, 'https://cdn.test/w1-original.webp');
    },
  );
}

class _FakeDetailsRepository implements WallpaperDetailsRepository {
  _FakeDetailsRepository(this.result);
  final Either<Failure, WallpaperEntity> result;

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(
    String idOrSlug,
  ) async => result;

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
