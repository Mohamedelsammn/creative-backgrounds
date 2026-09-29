import 'dart:io';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/error/error_handler.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Phase 12: applying a depth wallpaper must validate its preconditions
/// rather than silently degrading. The bug this covers: if the user
/// explicitly turned the depth effect on, but its cut-out foreground was
/// missing or failed to download, the apply used to fall back to a flat
/// background+clock wallpaper with no error at all - the user would have no
/// idea the effect they asked for never actually applied. Depth apply must
/// now fail with a clear, recoverable message in that case instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity depthWallpaper({String? foregroundMaskUrl}) => WallpaperEntity(
        id: 'w1',
        title: 'Depth wallpaper',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
        fullUrl: 'https://cdn.test/w1-flattened.webp',
        backgroundUrl: 'https://cdn.test/w1-background.webp',
        foregroundMaskUrl: foregroundMaskUrl,
        hasForegroundMask: foregroundMaskUrl != null,
        resolution: '1080x1920',
      );

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

  test(
      'a wallpaper with no foreground at all never claims depthEnabled in '
      'the first place (wallpaper.supportsDepth gates it), so it applies as '
      'a normal flattened image rather than failing - there is nothing to '
      'fail, since the effect was never actually offered', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-flattened.webp',
      });
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    final result = await repo.apply(
      wallpaper: depthWallpaper(foregroundMaskUrl: null),
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
    );

    expect(result.isRight(), isTrue);
  });

  test(
      'a wallpaper that DOES support depth, but whose foreground fails to '
      'download at apply time, fails with a clear recoverable message '
      'instead of silently applying a flat wallpaper', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-background.webp',
        // foreground URL deliberately absent -> the download throws
      });
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    final result = await repo.apply(
      wallpaper: depthWallpaper(
        foregroundMaskUrl: 'https://cdn.test/w1-foreground.webp',
      ),
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure, isA<DepthForegroundMissingFailure>());
        expect(
          ErrorHandler.mapFailureToMessage(failure),
          contains('depth effect'),
        );
      },
      (_) => fail('expected a Left(DepthForegroundMissingFailure)'),
    );
  });

  test('depth enabled with both layers downloading successfully applies '
      'normally', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-background.webp',
        'https://cdn.test/w1-foreground.webp',
      });
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    final result = await repo.apply(
      wallpaper: depthWallpaper(
        foregroundMaskUrl: 'https://cdn.test/w1-foreground.webp',
      ),
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
    );

    expect(result.isRight(), isTrue);
  });

  test('depth NOT enabled with a missing foreground still applies fine - '
      'the foreground is only required when depth was actually turned on',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-flattened.webp',
      });
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    final result = await repo.apply(
      wallpaper: depthWallpaper(foregroundMaskUrl: null),
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: false),
    );

    expect(result.isRight(), isTrue);
  });

  test(
      'a live (depth-enabled) apply persists its background/mask under the '
      'app support directory, never the OS-clearable temp directory the '
      'engine could lose behind the app\'s back between engine recreations',
      () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-background.webp',
        'https://cdn.test/w1-foreground.webp',
      });
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    String? capturedImagePath;
    String? capturedMaskPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      (call) async {
        if (call.method == 'applyWallpaper') {
          capturedImagePath = call.arguments['imagePath'] as String?;
          capturedMaskPath = call.arguments['maskPath'] as String?;
          return true;
        }
        return null;
      },
    );

    final result = await repo.apply(
      wallpaper: depthWallpaper(
        foregroundMaskUrl: 'https://cdn.test/w1-foreground.webp',
      ),
      destination: ApplyDestination.both,
      depthConfig: const DepthConfigEntity(wallpaperId: 'w1', enabled: true),
    );

    expect(result.isRight(), isTrue);
    final supportPath = await PathProviderPlatform.instance.getApplicationSupportPath();
    expect(capturedImagePath, contains(supportPath),
        reason: 'LiveWallpaperService reads this path back on every future '
            'engine recreation (unlock, reboot, launcher restart) for as '
            'long as the wallpaper stays applied - the OS temp/cache dir can '
            'be cleared at any time with no notice, which used to leave the '
            'engine falling back to a poster/placeholder forever');
    expect(capturedMaskPath, contains(supportPath));
  });
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
    // A depth/clock/video apply is the "live" path, which persists its
    // assets here instead of the temp dir - see
    // ApplyWallpaperRepositoryImpl._liveAssetsDir's doc. Cached across calls
    // within one test so repeated applies in the same test see the same
    // directory, matching the real platform's stable app-support path.
    _supportDir ??= await Directory.systemTemp.createTemp('apply_support_test_');
    return _supportDir!.path;
  }
}

/// Minimal Dio HttpClientAdapter: URLs in [okUrls] return a tiny successful
/// byte response; anything else throws, simulating a real download failure.
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
