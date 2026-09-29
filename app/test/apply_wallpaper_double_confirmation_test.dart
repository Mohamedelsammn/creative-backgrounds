import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 11: applying a live/depth wallpaper only ever launches Android's
/// system live-wallpaper picker - it does not (and cannot) wait for the user
/// to actually confirm there. The bug was that the app treated that launch as
/// final success and immediately showed its own "Done!" screen, so the user
/// saw the app claim success and then, moments later, Android's own picker
/// asking them to confirm - reading as a double apply.
///
/// The fix: `ApplyWallpaperSuccess.isLive` distinguishes the two cases, and
/// the sheet only navigates to the Done screen when `isLive` is false (a
/// static wallpaper, where `WallpaperManager.setBitmap` really did complete
/// with no further system UI). This tests that `isLive` is computed
/// correctly for every combination the apply sheet can produce.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  final staticWallpaper = WallpaperEntity(
    id: 'w1',
    title: 'Static',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1.webp',
    fullUrl: 'https://cdn.test/w1.webp',
    resolution: '1080x1920',
  );

  ApplyWallpaperBloc bloc(bool applyResult) => ApplyWallpaperBloc(
        ApplyWallpaperUseCase(_FakeApplyRepository(applyResult)),
      );

  test('a static wallpaper (no clock, no depth) reports isLive: false',
      () async {
    final b = bloc(true);
    b.add(ApplyWallpaperRequested(
      wallpaper: staticWallpaper,
      destination: ApplyDestination.homeScreen,
    ));

    final state =
        await b.stream.firstWhere((s) => s is ApplyWallpaperSuccess)
            as ApplyWallpaperSuccess;
    expect(state.isLive, isFalse);
    await b.close();
  });

  test(
      'a LIVE VIDEO wallpaper reports isLive: true even with no clock or '
      'depth config at all - Details opens the sheet for it with neither, '
      'and it is still applied via the same fire-and-forget system picker '
      'as a clock/depth wallpaper', () async {
    final videoWallpaper = WallpaperEntity(
      id: 'w2',
      title: 'Video',
      category: category,
      type: WallpaperType.live,
      thumbnailUrl: 'https://cdn.test/w2.webp',
      fullUrl: 'https://cdn.test/w2.webp',
      resolution: '1080x1920',
    );
    final b = bloc(true);
    b.add(ApplyWallpaperRequested(
      wallpaper: videoWallpaper,
      destination: ApplyDestination.both,
    ));

    final state =
        await b.stream.firstWhere((s) => s is ApplyWallpaperSuccess)
            as ApplyWallpaperSuccess;
    expect(state.isLive, isTrue);
    await b.close();
  });

  test('a wallpaper with a clock config reports isLive: true', () async {
    final b = bloc(true);
    b.add(ApplyWallpaperRequested(
      wallpaper: staticWallpaper,
      destination: ApplyDestination.both,
      clockConfig: const ClockConfigEntity(),
    ));

    final state =
        await b.stream.firstWhere((s) => s is ApplyWallpaperSuccess)
            as ApplyWallpaperSuccess;
    expect(state.isLive, isTrue);
    await b.close();
  });

  test('a wallpaper with depth ENABLED reports isLive: true', () async {
    final b = bloc(true);
    b.add(ApplyWallpaperRequested(
      wallpaper: staticWallpaper,
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
    ));

    final state =
        await b.stream.firstWhere((s) => s is ApplyWallpaperSuccess)
            as ApplyWallpaperSuccess;
    expect(state.isLive, isTrue);
    await b.close();
  });

  test('a wallpaper with depth present but DISABLED reports isLive: false - '
      'the depth object alone does not make it a live apply', () async {
    final b = bloc(true);
    b.add(ApplyWallpaperRequested(
      wallpaper: staticWallpaper,
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: false),
    ));

    final state =
        await b.stream.firstWhere((s) => s is ApplyWallpaperSuccess)
            as ApplyWallpaperSuccess;
    expect(state.isLive, isFalse);
    await b.close();
  });

  test('a failed apply never reports isLive at all - it is an error state',
      () async {
    final b = bloc(false);
    b.add(ApplyWallpaperRequested(
      wallpaper: staticWallpaper,
      destination: ApplyDestination.homeScreen,
    ));

    final state = await b.stream
        .firstWhere((s) => s is ApplyWallpaperSuccess || s is ApplyWallpaperError);
    expect(state, isA<ApplyWallpaperError>());
    await b.close();
  });
}

class _FakeApplyRepository implements ApplyWallpaperRepository {
  _FakeApplyRepository(this.result);
  final bool result;

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async {
    return result ? Right(result) : const Left(WallpaperApplyFailure());
  }
}
