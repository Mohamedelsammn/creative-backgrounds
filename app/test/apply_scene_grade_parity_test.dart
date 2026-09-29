import 'dart:io';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Section 10's parity audit found a real gap: `studio.scene` (a colour
/// grade - contrast/warmth/vignette/etc.) is baked into `STYLED_PREVIEW` and
/// Details already prefers that asset (`resolveDetailsVisual`), but Apply
/// downloaded [WallpaperEntity.fullUrl] unconditionally - the raw, ungraded
/// original/`PREVIEW`. Verified against production: `red-earth` carries a
/// real grade (contrast +0.1, warmth +0.35) baked into its `STYLED_PREVIEW`,
/// so Details showed the graded look and Apply silently reverted to the flat
/// original - Dashboard, Details and Applied all disagreed for exactly the
/// wallpapers `studio.scene` exists to author.
///
/// `WallpaperEntity.applyBackgroundUrl` closes this the same way
/// `resolveDetailsVisual` closed it for Details: by consuming the backend's
/// own server-rendered composite, not by building a second, independent
/// colour-grading engine. Depth is deliberately excluded - see that
/// getter's own doc for why a flattened composite cannot be decomposed back
/// into background+foreground layers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  setUp(() {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      (call) async => call.method == 'applyWallpaper' ? true : null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      null,
    );
  });

  group('WallpaperEntity.applyBackgroundUrl', () {
    test('prefers STYLED_PREVIEW when a scene grade was baked', () {
      final w = WallpaperEntity(
        id: 'w1',
        title: 'Graded',
        category: category,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
        design: const StudioDesign(
          styledPreviewUrl: 'https://cdn.test/styled-preview-hash.webp',
        ),
      );
      expect(w.applyBackgroundUrl, 'https://cdn.test/styled-preview-hash.webp');
    });

    test('falls back to fullUrl when there is no baked preview', () {
      final w = WallpaperEntity(
        id: 'w1',
        title: 'Ungraded',
        category: category,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
      );
      expect(w.applyBackgroundUrl, 'https://cdn.test/raw-preview.webp');
    });

    test('falls back to fullUrl when studio exists but never baked one', () {
      final w = WallpaperEntity(
        id: 'w1',
        title: 'Authored but never rendered',
        category: category,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
        design: const StudioDesign(
          clock: null,
          styledPreviewUrl: null,
        ),
      );
      expect(w.applyBackgroundUrl, 'https://cdn.test/raw-preview.webp');
    });
  });

  test(
    'a graded STANDARD wallpaper downloads the STYLED_PREVIEW bytes, not '
    'the raw original',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(okUrls: const {
          'https://cdn.test/styled-preview-hash.webp',
        });
      final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

      final wallpaper = WallpaperEntity(
        id: 'w1',
        title: 'Graded standard',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        // The raw asset deliberately has NO fake-adapter entry - if the
        // repository regresses to downloading this instead, the fake
        // adapter throws and the apply fails, failing this test.
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
        design: const StudioDesign(
          styledPreviewUrl: 'https://cdn.test/styled-preview-hash.webp',
        ),
      );

      final result = await repo.apply(
        wallpaper: wallpaper,
        destination: ApplyDestination.both,
      );

      expect(
        result.isRight(),
        isTrue,
        reason:
            'apply must succeed by downloading STYLED_PREVIEW - if it were '
            'still downloading the raw original this would fail, since '
            'only the styled url is registered with the fake adapter',
      );
    },
  );

  test(
    'a "Wallpaper Only" apply (no clockConfig/widgets/dateWidget) still '
    'downloads the graded STYLED_PREVIEW, not the raw original - the scene '
    'grade is baked into the artwork itself, not part of the "design" that '
    'choice suppresses',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(okUrls: const {
          'https://cdn.test/styled-preview-hash.webp',
        });
      final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

      final wallpaper = WallpaperEntity(
        id: 'w1',
        title: 'Graded standard',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/raw-preview.webp',
        resolution: '1080x1920',
        design: const StudioDesign(
          styledPreviewUrl: 'https://cdn.test/styled-preview-hash.webp',
        ),
      );

      // The exact call shape `_ApplySheetState` sends for "Wallpaper Only":
      // no clockConfig, no widgets, no dateWidget.
      final result = await repo.apply(
        wallpaper: wallpaper,
        destination: ApplyDestination.both,
      );

      expect(result.isRight(), isTrue);
    },
  );

  test(
    'a depth wallpaper still downloads the RAW background plate even when '
    'a styled preview exists, since a flattened composite cannot be '
    'decomposed back into background+foreground layers',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(okUrls: const {
          'https://cdn.test/raw-background.webp',
          'https://cdn.test/foreground.webp',
        });
      final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

      final wallpaper = WallpaperEntity(
        id: 'w1',
        title: 'Graded depth (hypothetical)',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/flattened-fallback.webp',
        backgroundUrl: 'https://cdn.test/raw-background.webp',
        foregroundMaskUrl: 'https://cdn.test/foreground.webp',
        hasForegroundMask: true,
        resolution: '1080x1920',
        design: const StudioDesign(
          // Even if the backend ever bakes one for depth, it must not be
          // used as the base layer - see the getter's own doc.
          styledPreviewUrl: 'https://cdn.test/styled-preview-hash.webp',
        ),
      );

      final result = await repo.apply(
        wallpaper: wallpaper,
        destination: ApplyDestination.both,
        depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
      );

      expect(result.isRight(), isTrue);
    },
  );
}

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  Directory? _supportDir;

  @override
  Future<String?> getTemporaryPath() async {
    final dir = await Directory.systemTemp.createTemp('apply_test_');
    return dir.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    _supportDir ??=
        await Directory.systemTemp.createTemp('apply_support_test_');
    return _supportDir!.path;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.okUrls});
  final Set<String> okUrls;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (okUrls.contains(options.uri.toString())) {
      return ResponseBody.fromBytes(const [1, 2, 3, 4], 200);
    }
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'simulated failure',
    );
  }

  @override
  void close({bool force = false}) {}
}
