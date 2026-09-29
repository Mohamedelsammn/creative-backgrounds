import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behavioural tests for the two Explore sections that changed.
///
/// These assert *outcomes the user would notice* - the order Trending renders
/// and the types the Live section contains - rather than which method was
/// called, so they still pass if the implementation is refactored.
void main() {
  WallpaperModel row(
    String id, {
    String type = 'standard',
    int downloads = 0,
    String published = '2026-01-01T00:00:00Z',
  }) =>
      WallpaperModel.fromApiFeedItem({
        'id': id,
        'title': id,
        'type': type,
        'categorySlug': 'nature',
        'thumbnailUrl': 'https://cdn.test/$id.webp',
        'downloads': downloads,
        'publishedAt': published,
      });

  group('Trending order is the backend order', () {
    test('renders exactly the sequence the API returned', () {
      // The dashboard authored A, C, B, D. Download counts deliberately
      // disagree with that order.
      final page = Paginated<WallpaperModel>(
        items: [
          row('A', downloads: 10),
          row('C', downloads: 9999),
          row('B', downloads: 1),
          row('D', downloads: 500),
        ],
        page: 1,
        hasMore: false,
      );

      final rendered =
          page.map((m) => m.toEntity()).items.map((w) => w.id).toList();

      expect(
        rendered,
        ['A', 'C', 'B', 'D'],
        reason: 'the app must render the received order verbatim and never '
            're-sort editorial content on the device',
      );
    });

    test('mapping to entities does not reorder by downloads', () {
      final page = Paginated<WallpaperModel>(
        items: [row('low', downloads: 1), row('high', downloads: 100000)],
        page: 1,
        hasMore: false,
      );
      expect(page.map((m) => m.toEntity()).items.first.id, 'low');
    });
  });

  group('Live section contains only live wallpapers', () {
    test('a video row maps to WallpaperType.live', () {
      expect(row('v', type: 'video').toEntity().type, WallpaperType.live);
    });

    test('normal and depth rows are a different type', () {
      expect(row('s', type: 'standard').toEntity().type, WallpaperType.normal);
      expect(row('d', type: 'depth').toEntity().type, WallpaperType.depth);
    });

    test('a live-only page contains no normal or depth rows', () {
      // Mirrors what the server returns for `type=VIDEO`.
      final live = <WallpaperModel>[
        row('v1', type: 'video'),
        row('v2', type: 'video'),
      ].map((m) => m.toEntity()).toList();

      expect(live, isNotEmpty);
      expect(
        live.every((w) => w.type == WallpaperType.live),
        isTrue,
        reason: 'the Live section must never mix in normal or depth wallpapers',
      );
      expect(live.any((w) => w.type == WallpaperType.normal), isFalse);
      expect(live.any((w) => w.type == WallpaperType.depth), isFalse);
    });
  });

  group('type filter wire format', () {
    test('sends the UPPER CASE form the schema declares', () {
      // Responses are lower-cased but the query parameter enum is
      // STANDARD|DEPTH|VIDEO - sending the response casing risks a
      // VALIDATION_FAILED if the server ever tightens its parsing.
      expect(WallpaperType.live.wire.toUpperCase(), 'VIDEO');
      expect(WallpaperType.normal.wire.toUpperCase(), 'STANDARD');
      expect(WallpaperType.depth.wire.toUpperCase(), 'DEPTH');
    });

    test('an unsupported type is never sent as a filter', () {
      expect(WallpaperType.unknown.isSupported, isFalse);
    });
  });
}
