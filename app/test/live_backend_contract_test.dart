import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/core/network/paginated_parser.dart';
import 'package:creativebackground/features/explore/data/models/category_model.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses **real captured responses** from the production backend through the
/// app's own parsers.
///
/// The fixtures under `assets/` are hand-written and can drift from what the
/// server actually sends. These payloads were captured live, so they catch the
/// kind of mismatch a hand-written fixture hides - a null field the model
/// assumed was present, or an asset kind that never arrives.
///
/// Captured 2026-08-25 from
/// https://creative-backgrounds.arabplus4tech.com/api/v1/public
void main() {
  final feed = jsonDecode(
    File('test/fixtures/live_feed.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final detail = jsonDecode(
    File('test/fixtures/live_detail_standard.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final videoDetail = jsonDecode(
    File('test/fixtures/live_detail_video.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final categories = jsonDecode(
    File('test/fixtures/live_categories.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('live feed', () {
    test('every row parses without throwing', () {
      final page =
          parsePaginatedResponse(feed, WallpaperModel.fromApiFeedItem);
      expect(page.items, isNotEmpty);
      // parseDataList silently skips unparseable rows, so compare counts to be
      // sure nothing was dropped.
      expect(page.items.length, (feed['data'] as List).length);
    });

    test('types map to the app vocabulary', () {
      final page =
          parsePaginatedResponse(feed, WallpaperModel.fromApiFeedItem);
      for (final w in page.items.map((m) => m.toEntity())) {
        expect(
          w.type,
          isNot(WallpaperType.unknown),
          reason: 'unrecognised backend type for "${w.title}"',
        );
      }
    });

    test('the live catalog contains at least one video wallpaper', () {
      final page =
          parsePaginatedResponse(feed, WallpaperModel.fromApiFeedItem);
      final live = page.items
          .map((m) => m.toEntity())
          .where((w) => w.type == WallpaperType.live);
      expect(
        live,
        isNotEmpty,
        reason: 'the Live Wallpapers section would be empty on this catalog',
      );
    });

    test('every row has a usable thumbnail', () {
      final page =
          parsePaginatedResponse(feed, WallpaperModel.fromApiFeedItem);
      for (final w in page.items.map((m) => m.toEntity())) {
        expect(w.thumbnailUrl, isNotEmpty, reason: 'no thumbnail: ${w.title}');
        expect(w.thumbnailUrl, startsWith('http'));
      }
    });

    test('list rows never expose a full-resolution URL', () {
      final page =
          parsePaginatedResponse(feed, WallpaperModel.fromApiFeedItem);
      for (final w in page.items.map((m) => m.toEntity())) {
        expect(w.fullUrl, w.thumbnailUrl);
      }
    });
  });

  group('live detail', () {
    test('a standard wallpaper with only a THUMBNAIL asset still resolves', () {
      // The production catalog currently ships standard wallpapers whose
      // `assets` map contains THUMBNAIL alone - no ORIGINAL, no PREVIEW. The
      // fallback chain must still yield a paintable URL rather than an empty
      // string, or Details would render a broken image.
      final w = WallpaperModel.fromApiDetail(detail).toEntity();
      expect(w.isDetailed, isTrue);
      expect(w.fullUrl, isNotEmpty);
      expect(w.fullUrl, startsWith('http'));
      expect(w.thumbnailUrl, isNotEmpty);
    });

    test('category is localised from the nested object', () {
      final w = WallpaperModel.fromApiDetail(detail).toEntity();
      expect(w.category.name, isNotEmpty);
      expect(w.category.displayName('ar'), isNotEmpty);
      expect(w.category.slug, isNotEmpty);
    });

    test('a standard wallpaper is not treated as depth', () {
      final w = WallpaperModel.fromApiDetail(detail).toEntity();
      expect(w.type, WallpaperType.normal);
      expect(w.supportsDepth, isFalse);
    });

    test('a video wallpaper exposes a playable clip', () {
      final w = WallpaperModel.fromApiDetail(videoDetail).toEntity();
      expect(w.type, WallpaperType.live);
      expect(w.video, isNotNull);
      expect(w.video!.url, startsWith('http'));
      expect(w.video!.mime, 'video/mp4');
      expect(w.video!.durationMs, greaterThan(0));
    });
  });

  group('live categories', () {
    test('all parse and carry both locales', () {
      final list = parseDataList(categories, CategoryModel.fromApi)
          .map((c) => c.toEntity())
          .toList();
      expect(list, isNotEmpty);
      for (final c in list) {
        expect(c.slug, isNotEmpty);
        expect(c.name, isNotEmpty);
        expect(c.displayName('en'), isNotEmpty);
        expect(c.displayName('ar'), isNotEmpty);
      }
    });

    test('a null colour does not break parsing', () {
      // The live catalog returns `color: null` for every category today.
      final list = parseDataList(categories, CategoryModel.fromApi)
          .map((c) => c.toEntity())
          .toList();
      expect(list.any((c) => c.color == null), isTrue);
    });

    test(
      'the CURRENT production field is "imageUrl", not "coverThumbnailUrl" '
      'or "iconUrl" - every approved category carries a real one, only the '
      'retired "cities" does not',
      () {
        final list = parseDataList(categories, CategoryModel.fromApi)
            .map((c) => c.toEntity())
            .toList();
        final bySlug = {for (final c in list) c.slug: c};

        for (final slug in [
          'nature',
          'amoled',
          'space',
          'cars',
          'anime',
          'minimal',
          'abstract',
          'animals',
        ]) {
          final url = bySlug[slug]?.thumbnailUrl;
          expect(url, isNotNull, reason: '$slug should carry a cover image');
          expect(url, startsWith('http'), reason: slug);
        }

        expect(bySlug['cities']?.thumbnailUrl, isNull,
            reason: 'the retired category genuinely has none');
      },
    );
  });
}
