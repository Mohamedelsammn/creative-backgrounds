import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 16: `WallpaperEntity.isLiveApply` is the single source of truth for
/// whether an apply only launches Android's system picker (fire-and-forget)
/// rather than completing synchronously - previously this was duplicated
/// between `_ApplySheet._isLive` and `ApplyWallpaperBloc._onRequested`, kept
/// in sync only by a comment, and a video wallpaper (which carries neither a
/// clock nor a depth config) fell through both of them.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(WallpaperType type) => WallpaperEntity(
        id: 'w1',
        title: 'Wallpaper',
        category: category,
        type: type,
        thumbnailUrl: 'https://cdn.test/w1.webp',
        fullUrl: 'https://cdn.test/w1.webp',
        resolution: '1080x1920',
      );

  test('a normal wallpaper with no clock/depth config is not a live apply',
      () {
    expect(wallpaper(WallpaperType.normal).isLiveApply(), isFalse);
  });

  test('a video wallpaper is always a live apply, even with no config at '
      'all - this is the exact gap that used to fall through', () {
    expect(wallpaper(WallpaperType.live).isLiveApply(), isTrue);
  });

  test('a normal wallpaper with a clock config is a live apply', () {
    expect(
      wallpaper(WallpaperType.normal)
          .isLiveApply(clockConfig: const ClockConfigEntity()),
      isTrue,
    );
  });

  test('a normal wallpaper with depth ENABLED is a live apply', () {
    expect(
      wallpaper(WallpaperType.depth).isLiveApply(
        depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
      ),
      isTrue,
    );
  });

  test('a wallpaper with depth present but DISABLED is not a live apply', () {
    expect(
      wallpaper(WallpaperType.depth).isLiveApply(
        depthConfig:
            const DepthConfigEntity(wallpaperId: 'w1', enabled: false),
      ),
      isFalse,
    );
  });
}
