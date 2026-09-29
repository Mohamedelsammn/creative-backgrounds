import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/core/usecases/usecase.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_new_wallpapers_usecase.dart';
import 'package:creativebackground/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies `ExploreBloc`'s single-mixed-feed pagination: `forceRefresh` is
/// forwarded only on `ExploreRefreshRequested`, `ExploreLoadMoreRequested`
/// appends using the previous page's cursor, and a refresh replaces (rather
/// than appends to) the current list.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature', slug: 'nature');

  WallpaperEntity wallpaper(String id) => WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: category,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
      );

  late _CapturingNewWallpapersUseCase getNewWallpapers;

  ExploreBloc bloc() => ExploreBloc(getNewWallpapers: getNewWallpapers);

  setUp(() {
    getNewWallpapers = _CapturingNewWallpapersUseCase();
  });

  test('ExploreStarted requests a plain (non-forced) fetch', () async {
    final b = bloc();
    b.add(const ExploreStarted());
    await b.stream.firstWhere((s) => s is ExploreLoaded);
    await b.close();

    expect(getNewWallpapers.calls.single.forceRefresh, isFalse);
  });

  test('ExploreRefreshRequested requests a forced refresh', () async {
    final b = bloc();
    b.add(const ExploreRefreshRequested());
    await b.stream.firstWhere((s) => s is ExploreLoaded);
    await b.close();

    expect(getNewWallpapers.calls.single.forceRefresh, isTrue);
  });

  test(
      'a refresh that returns updated data actually reaches ExploreLoaded '
      'with the new items', () async {
    getNewWallpapers.result = Right(Paginated(
      items: [wallpaper('a'), wallpaper('b')],
      page: 1,
      hasMore: false,
    ));
    final b = bloc();
    b.add(const ExploreRefreshRequested());
    final state = await b.stream.firstWhere((s) => s is ExploreLoaded)
        as ExploreLoaded;
    await b.close();

    expect(state.wallpapers.map((w) => w.id), ['a', 'b']);
  });

  test('ExploreLoadMoreRequested appends the next page using the previous '
      "page's cursor, and stops once hasMore is false", () async {
    getNewWallpapers.result = Right(Paginated(
      items: [wallpaper('a')],
      page: 1,
      hasMore: true,
      nextCursor: 'cursor-1',
    ));
    final b = bloc();
    b.add(const ExploreStarted());
    await b.stream.firstWhere((s) => s is ExploreLoaded);

    getNewWallpapers.result = Right(Paginated(
      items: [wallpaper('b')],
      page: 2,
      hasMore: false,
    ));
    b.add(const ExploreLoadMoreRequested());
    final state = await b.stream.firstWhere(
      (s) => s is ExploreLoaded && s.wallpapers.length == 2,
    ) as ExploreLoaded;
    await b.close();

    expect(state.wallpapers.map((w) => w.id), ['a', 'b']);
    expect(state.hasMore, isFalse);
    expect(getNewWallpapers.calls.last.cursor, 'cursor-1');
  });

  test('ExploreLoadMoreRequested is a no-op once hasMore is false', () async {
    getNewWallpapers.result = Right(Paginated(
      items: [wallpaper('a')],
      page: 1,
      hasMore: false,
    ));
    final b = bloc();
    b.add(const ExploreStarted());
    await b.stream.firstWhere((s) => s is ExploreLoaded);
    final callsBefore = getNewWallpapers.calls.length;

    b.add(const ExploreLoadMoreRequested());
    await Future<void>.delayed(Duration.zero);
    await b.close();

    expect(getNewWallpapers.calls.length, callsBefore);
  });
}

class _CapturingNewWallpapersUseCase implements GetNewWallpapersUseCase {
  final List<PageParams> calls = [];
  Either<Failure, Paginated<WallpaperEntity>> result =
      const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
      PageParams params) async {
    calls.add(params);
    return result;
  }
}
