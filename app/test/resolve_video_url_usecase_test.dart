import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/explore/domain/repositories/explore_repository.dart';
import 'package:creativebackground/features/explore/domain/usecases/resolve_video_url_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 5: the backend can now include the `video` object directly on a feed
/// row (verified against the fixture, which mirrors the real API shape).
/// `ResolveVideoUrlUseCase` must recognise that and skip the network
/// entirely - hitting the detail endpoint anyway would be a duplicate
/// request for information the card already has.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  const video = VideoAsset(
    url: 'https://cdn.test/clip.mp4',
    mime: 'video/mp4',
    width: 1080,
    height: 1920,
    durationMs: 8000,
    fps: 30,
    sizeBytes: 4200000,
    codec: 'h264',
  );

  WallpaperEntity liveWallpaper({VideoAsset? video}) => WallpaperEntity(
        id: 'w1',
        title: 'Live wallpaper',
        category: category,
        type: WallpaperType.live,
        thumbnailUrl: 'https://cdn.test/w1.webp',
        fullUrl: 'https://cdn.test/w1.webp',
        resolution: '1080x1920',
        video: video,
      );

  test('a feed row that already carries video makes zero network requests',
      () async {
    final repo = _CountingExploreRepository();
    final useCase = ResolveVideoUrlUseCase(repo);

    final url = await useCase(liveWallpaper(video: video));

    expect(url, 'https://cdn.test/clip.mp4');
    expect(repo.detailCallCount, 0);
  });

  test('a live row with no video falls back to the detail endpoint once',
      () async {
    final repo = _CountingExploreRepository(detailUrl: 'https://cdn.test/resolved.mp4');
    final useCase = ResolveVideoUrlUseCase(repo);

    final url = await useCase(liveWallpaper());

    expect(url, 'https://cdn.test/resolved.mp4');
    expect(repo.detailCallCount, 1);
  });

  test('a resolved clip is cached, so scrolling back never refetches',
      () async {
    final repo = _CountingExploreRepository(detailUrl: 'https://cdn.test/resolved.mp4');
    final useCase = ResolveVideoUrlUseCase(repo);
    final w = liveWallpaper();

    await useCase(w);
    await useCase(w);
    await useCase(w);

    expect(repo.detailCallCount, 1);
  });

  test('concurrent calls for the same wallpaper share one in-flight request',
      () async {
    final repo = _CountingExploreRepository(detailUrl: 'https://cdn.test/resolved.mp4');
    final useCase = ResolveVideoUrlUseCase(repo);
    final w = liveWallpaper();

    final results = await Future.wait([useCase(w), useCase(w), useCase(w)]);

    expect(results, everyElement('https://cdn.test/resolved.mp4'));
    expect(repo.detailCallCount, 1);
  });

  test('a non-live wallpaper never triggers a lookup at all', () async {
    final repo = _CountingExploreRepository();
    final useCase = ResolveVideoUrlUseCase(repo);
    final normal = WallpaperEntity(
      id: 'w2',
      title: 'Normal wallpaper',
      category: category,
      thumbnailUrl: 'https://cdn.test/w2.webp',
      fullUrl: 'https://cdn.test/w2.webp',
      resolution: '1080x1920',
    );

    final url = await useCase(normal);

    expect(url, isNull);
    expect(repo.detailCallCount, 0);
  });
}

class _CountingExploreRepository implements ExploreRepository {
  _CountingExploreRepository({this.detailUrl});

  final String? detailUrl;
  int detailCallCount = 0;

  @override
  Future<Either<Failure, String?>> getWallpaperVideoUrl(String idOrSlug) async {
    detailCallCount++;
    return Right(detailUrl);
  }

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getLiveWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getDepthWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const Right(Paginated.empty());

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getNewWallpapers({
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const Right(Paginated.empty());

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool forceRefresh = false,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> getCategoryWallpapers({
    required String categorySlug,
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      const Right(Paginated.empty());
}
