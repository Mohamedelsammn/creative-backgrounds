import 'package:creativebackground/core/network/paginated_parser.dart';
import 'package:creativebackground/core/utils/color_utils.dart';
import 'package:creativebackground/features/clock/data/models/remote_clock_config_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/explore/data/models/model_mappers.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the public-API mapping layer.
///
/// These pin the behaviours that are easy to get silently wrong and expensive
/// to notice later: byte order of colors, the scale/size conversion, type
/// detection, and resilience to bad rows.
void main() {
  group('WallpaperType', () {
    test('maps the wire vocabulary, including video -> live', () {
      expect(WallpaperType.fromWire('standard'), WallpaperType.normal);
      expect(WallpaperType.fromWire('depth'), WallpaperType.depth);
      expect(WallpaperType.fromWire('video'), WallpaperType.live);
    });

    test('accepts the admin API upper-case spelling', () {
      expect(WallpaperType.fromWire('DEPTH'), WallpaperType.depth);
      expect(WallpaperType.fromWire('VIDEO'), WallpaperType.live);
    });

    test('degrades an unknown or absent type instead of throwing', () {
      expect(WallpaperType.fromWire('parallax'), WallpaperType.unknown);
      expect(WallpaperType.fromWire(null), WallpaperType.unknown);
      expect(WallpaperType.fromWire(42), WallpaperType.unknown);
      expect(WallpaperType.unknown.isSupported, isFalse);
    });
  });

  group('CSS hex colors', () {
    test('reads #RRGGBBAA with alpha last, not first', () {
      // The dashboard authors CSS. Reading this as #AARRGGBB would yield a
      // 20%-opaque teal instead of an 80%-opaque white.
      expect(parseCssHexColorToArgb('#FFFFFFCC'), 0xCCFFFFFF);
      expect(parseCssHexColorToArgb('#FFFFFF'), 0xFFFFFFFF);
      expect(parseCssHexColorToArgb('#000000'), 0xFF000000);
    });

    test('round-trips through argbToCssHex', () {
      expect(argbToCssHex(0xFFFFFFFF), '#ffffff');
      expect(argbToCssHex(0xCCFFFFFF), '#ffffffcc');
      expect(parseCssHexColorToArgb(argbToCssHex(0xCC123456)), 0xCC123456);
    });

    test('returns null on malformed input', () {
      expect(parseCssHexColorToArgb('nonsense'), isNull);
      expect(parseCssHexColorToArgb('#FFF'), isNull);
      expect(parseCssHexColorToArgb(null), isNull);
    });
  });

  group('RemoteClockConfigMapper', () {
    Map<String, dynamic> clockJson() => {
          'enabled': true,
          'style': 'outlined',
          'position': 'custom',
          'customX': 0.5,
          'customY': 0.22,
          'font': 'BebasNeue',
          'weight': 700,
          'scale': 1.5,
          'rotation': -4,
          'color': '#FFFFFFCC',
          'opacity': 0.9,
          'depth': 0.7,
          'shadow': {'enabled': true, 'strength': 0.6},
          'date': {'enabled': false, 'position': 'above', 'color': '#E8E8E8'},
          'schemaVersion': 1,
        };

    test('keeps scale and sizePx as independent size factors', () {
      final config = RemoteClockConfigMapper.fromJson(clockJson())!;
      expect(config.scale, 1.5);
      expect(config.sizePx, 65, reason: 'absent sizePx is 65, not derived');
    });

    test('resolves a custom position to the nearest anchor but keeps x/y', () {
      final config = RemoteClockConfigMapper.fromJson(clockJson())!;
      // customY 0.22 is in the top third.
      expect(config.position, ClockPosition.top);
      expect(config.customX, 0.5);
      expect(config.customY, 0.22);
      expect(config.hasCustomPosition, isTrue);
    });

    test('preserves the raw backend style and font verbatim', () {
      final config = RemoteClockConfigMapper.fromJson(clockJson())!;
      expect(config.remoteStyle, 'outlined');
      expect(config.remoteFont, 'BebasNeue');
      // ...while still mapping onto something this app can render.
      expect(config.style, ClockStyle.modern);
      expect(config.showStroke, isTrue, reason: 'outlined implies a stroke');
      expect(config.font, ClockFont.inter);
    });

    test('flattens the nested shadow and date objects', () {
      final config = RemoteClockConfigMapper.fromJson(clockJson())!;
      expect(config.showShadow, isTrue);
      expect(config.shadowStrength, 0.6);
      expect(config.showDate, isFalse);
      expect(config.datePosition, ClockDatePosition.above);
      expect(config.dateColor, 0xFFE8E8E8);
    });

    test('clamps out-of-range numbers rather than trusting them', () {
      final config = RemoteClockConfigMapper.fromJson({
        'scale': 99.0,
        'opacity': -3,
        'rotation': 900,
        'weight': 5000,
      })!;
      expect(config.scale, 3.0);
      expect(config.opacity, 0.0);
      expect(config.rotation, 180.0);
      expect(config.weight, 900);
    });

    test('falls back to defaults on wrong types', () {
      final config = RemoteClockConfigMapper.fromJson({
        'enabled': 'yes',
        'scale': 'big',
        'shadow': 'none',
        'date': 7,
      })!;
      expect(config.enabled, isTrue);
      expect(config.scale, 1.0);
      // An unreadable `shadow`/`date` sub-object means the author's intent is
      // unknown, so the feature stays OFF. Defaulting it ON would invent a
      // shadow and a date the dashboard never authored - and since every
      // production clock authors both objects explicitly (all of them with
      // `date.enabled: false`), ON could only ever appear on corrupt data.
      expect(config.showShadow, isFalse);
      expect(config.showDate, isFalse);
    });

    test('returns null when there is no clock at all', () {
      expect(RemoteClockConfigMapper.fromJson(null), isNull);
      expect(RemoteClockConfigMapper.fromJson('nope'), isNull);
    });

    test('round-trips through toJson without losing authored fields', () {
      final original = RemoteClockConfigMapper.fromJson(clockJson())!;
      final again =
          RemoteClockConfigMapper.fromJson(RemoteClockConfigMapper.toJson(original))!;
      expect(again.remoteStyle, original.remoteStyle);
      expect(again.remoteFont, original.remoteFont);
      expect(again.color, original.color);
      expect(again.scale, original.scale);
      expect(again.customY, original.customY);
      expect(again.shadowStrength, original.shadowStrength);
      expect(again.datePosition, original.datePosition);
    });
  });

  group('WallpaperModel.fromApiFeedItem', () {
    Map<String, dynamic> depthRow() => {
          'id': 'w-1',
          'slug': 'jet-sky',
          'title': 'Jet Sky',
          'type': 'depth',
          'width': 2160,
          'height': 3840,
          'resolutionLabel': '2160x3840',
          'dominantColor': '#2E4A6B',
          'isPremium': true,
          'isFeatured': true,
          'categorySlug': 'cars',
          'thumbnailUrl': 'https://cdn.test/jet-sky/thumb.webp',
          'background': 'https://cdn.test/jet-sky/bg.webp',
          'foreground': 'https://cdn.test/jet-sky/fg.png',
          'clockConfig': {'style': 'thin', 'color': '#FFFFFF', 'scale': 1.0},
          'depthConfig': {
            'foregroundScale': 1.15,
            'foregroundOffsetX': -0.04,
            'foregroundOffsetY': 0.08,
            'blurRadius': 12,
            'shadowStrength': 0.7,
          },
          'tags': [
            {'slug': 'sky', 'name': 'Sky'}
          ],
          'downloads': 20100,
          'fileSizeBytes': 8800000,
          'publishedAt': '2026-07-05T00:00:00Z',
        };

    test('never exposes a full-resolution URL on a list row', () {
      // Guards the browsing path: a list row must not let any widget pull a
      // multi-megabyte asset just to draw a card.
      final entity = WallpaperModel.fromApiFeedItem(depthRow()).toEntity();
      expect(entity.fullUrl, entity.thumbnailUrl);
      expect(entity.isDetailed, isFalse);
      // The layers are still carried, for the details-screen composite.
      expect(entity.backgroundUrl, 'https://cdn.test/jet-sky/bg.webp');
      expect(entity.foregroundMaskUrl, 'https://cdn.test/jet-sky/fg.png');
    });

    test('detects depth and reports it as compositable', () {
      final entity = WallpaperModel.fromApiFeedItem(depthRow()).toEntity();
      expect(entity.type, WallpaperType.depth);
      expect(entity.supportsDepth, isTrue);
      expect(entity.compositeBackgroundUrl, 'https://cdn.test/jet-sky/bg.webp');
      expect(entity.depthRenderConfig?.foregroundScale, 1.15);
      expect(entity.remoteClockConfig, isNotNull);
    });

    test('a depth row without layers is not compositable', () {
      final row = depthRow()
        ..remove('background')
        ..remove('foreground');
      final entity = WallpaperModel.fromApiFeedItem(row).toEntity();
      expect(entity.type, WallpaperType.depth);
      expect(entity.supportsDepth, isFalse);
    });

    test('parses a video row into a VideoAsset', () {
      final entity = WallpaperModel.fromApiFeedItem({
        'id': 'w-2',
        'slug': 'aurora-drift',
        'title': 'Aurora Drift',
        'type': 'video',
        'categorySlug': 'space',
        'thumbnailUrl': 'https://cdn.test/aurora/thumb.webp',
        'video': {
          'url': 'https://cdn.test/aurora/loop.mp4',
          'mime': 'video/mp4',
          'width': 1080,
          'height': 1920,
          'durationMs': 8000,
          'fps': 30,
          'sizeBytes': 4200000,
          'codec': 'h264',
        },
      }).toEntity();

      expect(entity.type, WallpaperType.live);
      expect(entity.video?.url, 'https://cdn.test/aurora/loop.mp4');
      expect(entity.video?.durationMs, 8000);
      expect(entity.video?.aspectRatio, closeTo(1080 / 1920, 0.0001));
    });

    test('flattens tag objects to names', () {
      final entity = WallpaperModel.fromApiFeedItem(depthRow()).toEntity();
      expect(entity.tags, ['Sky']);
    });

    test('synthesizes a readable category when the slug is unresolved', () {
      final entity = WallpaperModel.fromApiFeedItem({
        'id': 'w-3',
        'title': 'Orphan',
        'type': 'standard',
        'categorySlug': 'city-lights',
        'thumbnailUrl': 'https://cdn.test/x.webp',
      }).toEntity();
      expect(entity.category.name, 'City Lights');
      expect(entity.category.slug, 'city-lights');
    });

    test('survives a row that is almost entirely missing', () {
      final entity = WallpaperModel.fromApiFeedItem({'id': 'w-4'}).toEntity();
      expect(entity.id, 'w-4');
      expect(entity.type, WallpaperType.normal);
      expect(entity.title, isEmpty);
      expect(entity.tags, isEmpty);
      expect(entity.remoteClockConfig, isNull);
    });
  });

  group('WallpaperModel.fromApiDetail', () {
    test('upgrades fullUrl to the real asset and keeps list-only fields', () {
      final listRow = WallpaperModel.fromApiFeedItem({
        'id': 'w-1',
        'title': 'Jet Sky',
        'type': 'depth',
        'categorySlug': 'cars',
        'thumbnailUrl': 'https://cdn.test/thumb.webp',
        'downloads': 20100,
        'blurhash': 'LEHV6n',
      });

      final detail = WallpaperModel.fromApiDetail({
        'id': 'w-1',
        'slug': 'jet-sky',
        'title': 'Jet Sky',
        'description': 'A jet over open water.',
        'type': 'depth',
        'category': {'slug': 'cars', 'nameEn': 'Cars', 'nameAr': 'سيارات'},
        'thumbnail': 'https://cdn.test/thumb.webp',
        'background': 'https://cdn.test/bg.webp',
        'foreground': 'https://cdn.test/fg.png',
        'assets': {
          'ORIGINAL': {
            'url': 'https://cdn.test/original.webp',
            'mime': 'image/webp',
            'width': 2160,
            'height': 3840,
            'bytes': 9100000,
          },
        },
        'tags': const [],
      }, previous: listRow).toEntity();

      expect(detail.isDetailed, isTrue);
      expect(detail.fullUrl, 'https://cdn.test/original.webp');
      expect(detail.description, 'A jet over open water.');
      expect(detail.assets['ORIGINAL']?.bytes, 9100000);
      expect(detail.category.nameAr, 'سيارات');
      // The detail contract omits these; they must survive from the list row.
      expect(detail.downloadCount, 20100);
      expect(detail.blurhash, 'LEHV6n');
    });

    test('falls back through assets when flat URLs are absent', () {
      final detail = WallpaperModel.fromApiDetail({
        'id': 'w-9',
        'title': 'Assets only',
        'type': 'standard',
        'assets': {
          'THUMBNAIL': {'url': 'https://cdn.test/t.webp', 'mime': 'image/webp'},
          'PREVIEW': {'url': 'https://cdn.test/p.webp', 'mime': 'image/webp'},
        },
      }).toEntity();

      expect(detail.thumbnailUrl, 'https://cdn.test/t.webp');
      expect(detail.fullUrl, 'https://cdn.test/p.webp');
    });

    test(
        'a depth wallpaper with no ORIGINAL asset shows the composed '
        'thumbnail, never the bare background plate', () {
      // Reproduces the real production catalog: a depth wallpaper whose
      // `assets` map is only THUMBNAIL/BACKGROUND/FOREGROUND - no ORIGINAL is
      // ever stored for depth type. `background` alone is the empty-scene
      // plate with the subject cut out; showing it as "the wallpaper" was the
      // reported bug (Details rendered a scene with no subject and no clock).
      // `thumbnail` is the one asset the backend actually renders as the full
      // composed look (background + subject + clock), so it must win here.
      final detail = WallpaperModel.fromApiDetail({
        'id': 'w-depth-no-original',
        'title': 'Katana at the Torii',
        'type': 'depth',
        'thumbnail': 'https://cdn.test/thumbnail.webp',
        'background': 'https://cdn.test/background.webp',
        'foreground': 'https://cdn.test/foreground.webp',
        'assets': {
          'THUMBNAIL': {
            'url': 'https://cdn.test/thumbnail.webp',
            'mime': 'image/webp',
          },
          'BACKGROUND': {
            'url': 'https://cdn.test/background.webp',
            'mime': 'image/webp',
          },
          'FOREGROUND': {
            'url': 'https://cdn.test/foreground.webp',
            'mime': 'image/webp',
          },
        },
      }).toEntity();

      expect(detail.fullUrl, 'https://cdn.test/thumbnail.webp');
      expect(
        detail.fullUrl,
        isNot('https://cdn.test/background.webp'),
        reason: 'the background plate alone is missing the subject and the '
            'clock and must never stand in for the authored composition',
      );
      // The layers are still carried, so the editable Customize composite
      // (background -> clock -> foreground) keeps working unaffected.
      expect(detail.backgroundUrl, 'https://cdn.test/background.webp');
      expect(detail.foregroundMaskUrl, 'https://cdn.test/foreground.webp');
      expect(detail.supportsDepth, isTrue);
    });

    test('an ORIGINAL asset still wins over the thumbnail fallback for depth',
        () {
      // If the backend ever does publish a flattened original for a depth
      // wallpaper, it must be preferred - the thumbnail fallback is a
      // stand-in for a missing asset, not a rule that overrides a real one.
      final detail = WallpaperModel.fromApiDetail({
        'id': 'w-depth-with-original',
        'title': 'Has a real original',
        'type': 'depth',
        'thumbnail': 'https://cdn.test/thumbnail.webp',
        'background': 'https://cdn.test/background.webp',
        'assets': {
          'ORIGINAL': {
            'url': 'https://cdn.test/original.webp',
            'mime': 'image/webp',
          },
        },
      }).toEntity();

      expect(detail.fullUrl, 'https://cdn.test/original.webp');
    });
  });

  group('envelope parsing', () {
    test('reads the keyset feed envelope', () {
      final page = parsePaginatedResponse(
        {
          'data': [
            {'id': 'a', 'title': 'A', 'type': 'standard', 'thumbnailUrl': 'u'}
          ],
          'meta': {'nextCursor': 'abc123', 'hasMore': true},
        },
        WallpaperModel.fromApiFeedItem,
      );
      expect(page.items, hasLength(1));
      expect(page.nextCursor, 'abc123');
      expect(page.hasMore, isTrue);
    });

    test('reads the unpaginated search envelope', () {
      final page = parsePaginatedResponse(
        {
          'data': [
            {'id': 'a', 'title': 'A', 'type': 'standard', 'thumbnailUrl': 'u'}
          ]
        },
        WallpaperModel.fromApiFeedItem,
      );
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(page.total, 1);
    });

    test('reads the offset envelope', () {
      final page = parsePaginatedResponse(
        {
          'data': const [],
          'meta': {'page': 2, 'pageSize': 20, 'total': 55, 'totalPages': 3},
        },
        WallpaperModel.fromApiFeedItem,
      );
      expect(page.page, 2);
      expect(page.total, 55);
      expect(page.hasMore, isTrue);
    });

    test('keeps the good rows when one row is malformed', () {
      final page = parsePaginatedResponse(
        {
          'data': [
            {'id': 'a', 'title': 'A', 'type': 'standard', 'thumbnailUrl': 'u'},
            'not-an-object',
            {'id': 'b', 'title': 'B', 'type': 'depth', 'thumbnailUrl': 'u'},
          ],
          'meta': {'hasMore': false, 'nextCursor': null},
        },
        WallpaperModel.fromApiFeedItem,
      );
      expect(page.items.map((w) => w.id), ['a', 'b']);
    });

    test('an empty or absent data array yields an empty page', () {
      expect(
        parsePaginatedResponse({}, WallpaperModel.fromApiFeedItem).items,
        isEmpty,
      );
      expect(
        parsePaginatedResponse(
          {'data': const []},
          WallpaperModel.fromApiFeedItem,
        ).hasMore,
        isFalse,
      );
    });
  });

  group('favorites round-trip', () {
    test('a depth wallpaper survives entity -> model -> entity', () {
      // Favorites persist entities as models; losing the layers or the clock
      // here would silently downgrade a saved depth wallpaper to a flat image.
      final original = WallpaperModel.fromApiFeedItem({
        'id': 'w-1',
        'slug': 'jet-sky',
        'title': 'Jet Sky',
        'type': 'depth',
        'categorySlug': 'cars',
        'thumbnailUrl': 'https://cdn.test/thumb.webp',
        'background': 'https://cdn.test/bg.webp',
        'foreground': 'https://cdn.test/fg.png',
        'clockConfig': {'style': 'thin', 'color': '#FFFFFFCC', 'scale': 1.6},
        'depthConfig': {'foregroundScale': 1.15, 'blurRadius': 12},
      }).toEntity();

      final restored = original.toModel().toEntity();

      expect(restored.type, WallpaperType.depth);
      expect(restored.backgroundUrl, original.backgroundUrl);
      expect(restored.foregroundMaskUrl, original.foregroundMaskUrl);
      expect(restored.supportsDepth, isTrue);
      expect(restored.remoteClockConfig?.color, 0xCCFFFFFF);
      expect(restored.remoteClockConfig?.remoteStyle, 'thin');
      expect(restored.depthRenderConfig?.foregroundScale, 1.15);
    });

    test('a video wallpaper survives the same round-trip', () {
      final original = WallpaperModel.fromApiFeedItem({
        'id': 'w-2',
        'title': 'Aurora Drift',
        'type': 'video',
        'categorySlug': 'space',
        'thumbnailUrl': 'https://cdn.test/thumb.webp',
        'video': {
          'url': 'https://cdn.test/loop.mp4',
          'mime': 'video/mp4',
          'width': 1080,
          'height': 1920,
          'durationMs': 8000,
          'fps': 30,
          'sizeBytes': 4200000,
          'codec': 'h264',
        },
      }).toEntity();

      final restored = original.toModel().toEntity();
      expect(restored.type, WallpaperType.live);
      expect(restored.video?.url, 'https://cdn.test/loop.mp4');
      expect(restored.video?.fps, 30);
    });
  });
}
