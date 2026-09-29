import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart';
import 'package:creativebackground/features/clock/data/models/clock_config_model.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Root-cause regression test: customizing the clock on a LIVE (video)
/// wallpaper and applying it used to lose the clock entirely, because
/// `ApplyWallpaperRepositoryImpl.apply()`'s live-type branch called
/// `_applyVideo(wallpaper)` - a method that never accepted a `ClockConfigEntity`
/// parameter at all - discarding the customization before it was ever
/// serialized or sent over the channel, let alone reaching native code.
///
/// These tests cover the Dart-side half of the fix: the clock config must now
/// reach `WallpaperChannel.applyVideoWallpaper` as a JSON string, exactly like
/// it already does for the static/depth path via `applyWallpaper`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity liveWallpaper() => WallpaperEntity(
        id: 'w1',
        title: 'Live wallpaper',
        category: category,
        type: WallpaperType.live,
        thumbnailUrl: 'https://cdn.test/w1-thumb.webp',
        fullUrl: 'https://cdn.test/w1-thumb.webp',
        video: const VideoAsset(
          url: 'https://cdn.test/w1-clip.mp4',
          mime: 'video/mp4',
          width: 1080,
          height: 1920,
          durationMs: 10000,
          fps: 30,
          sizeBytes: 1024,
          codec: 'h264',
        ),
        resolution: '1080x1920',
      );

  setUp(() {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      null,
    );
  });

  test(
      'applying a LIVE wallpaper with a customized clock sends the serialized '
      'ClockConfigEntity to applyVideoWallpaper, not just the video/poster '
      'paths', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-clip.mp4',
        'https://cdn.test/w1-thumb.webp',
      });
    Map<dynamic, dynamic>? capturedArgs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      (call) async {
        if (call.method == 'applyVideoWallpaper') {
          capturedArgs = call.arguments as Map<dynamic, dynamic>;
          return true;
        }
        return null;
      },
    );
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    const clockConfig = ClockConfigEntity(
      enabled: true,
      color: 0xFFFF0000,
      sizePx: 80,
    );

    final result = await repo.apply(
      wallpaper: liveWallpaper(),
      destination: ApplyDestination.both,
      clockConfig: clockConfig,
    );

    expect(result.isRight(), isTrue);
    expect(capturedArgs, isNotNull);
    final clockJson = capturedArgs!['clockConfig'] as String?;
    expect(
      clockJson,
      isNotNull,
      reason: 'the clock customized in Customize must reach native for a '
          'video wallpaper apply exactly like it does for static/depth',
    );
    final decoded = jsonDecode(clockJson!) as Map<String, dynamic>;
    expect(decoded['enabled'], isTrue);
    expect(decoded['color'], 0xFFFF0000);
    expect(decoded['sizePx'], 80);

    // Round-trips through the same model the static/depth path uses, so
    // native's `ClockConfig.fromJson` parses it identically either way.
    final roundTripped = ClockConfigModel.fromJson(decoded);
    expect(roundTripped.toEntity(), clockConfig);
  });

  test(
      'applying a LIVE wallpaper with no clock configured sends a null '
      'clockConfig, not an empty/default one - so native clears any '
      'previously applied clock rather than drawing a stale one', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-clip.mp4',
        'https://cdn.test/w1-thumb.webp',
      });
    Map<dynamic, dynamic>? capturedArgs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      (call) async {
        if (call.method == 'applyVideoWallpaper') {
          capturedArgs = call.arguments as Map<dynamic, dynamic>;
          return true;
        }
        return null;
      },
    );
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    final result = await repo.apply(
      wallpaper: liveWallpaper(),
      destination: ApplyDestination.both,
    );

    expect(result.isRight(), isTrue);
    expect(capturedArgs!['clockConfig'], isNull);
  });

  test(
      're-applying the same live wallpaper with a DIFFERENT clock customization '
      'sends the new settings, not the previous call\'s', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter(okUrls: const {
        'https://cdn.test/w1-clip.mp4',
        'https://cdn.test/w1-thumb.webp',
      });
    final capturedJsons = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.backgrounds.trend4k/wallpaper'),
      (call) async {
        if (call.method == 'applyVideoWallpaper') {
          capturedJsons
              .add((call.arguments as Map)['clockConfig'] as String?);
          return true;
        }
        return null;
      },
    );
    final repo = ApplyWallpaperRepositoryImpl(WallpaperChannel(), dio: dio);

    await repo.apply(
      wallpaper: liveWallpaper(),
      destination: ApplyDestination.both,
      clockConfig: const ClockConfigEntity(enabled: true, color: 0xFFFF0000),
    );
    await repo.apply(
      wallpaper: liveWallpaper(),
      destination: ApplyDestination.both,
      clockConfig: const ClockConfigEntity(enabled: true, color: 0xFF00FF00),
    );

    expect(capturedJsons, hasLength(2));
    final first = jsonDecode(capturedJsons[0]!) as Map<String, dynamic>;
    final second = jsonDecode(capturedJsons[1]!) as Map<String, dynamic>;
    expect(first['color'], 0xFFFF0000);
    expect(second['color'], 0xFF00FF00);
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
    _supportDir ??= await Directory.systemTemp.createTemp('apply_support_test_');
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
