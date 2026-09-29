import 'package:creativebackground/core/fixtures/mock_catalog.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Trending section must show ONLY wallpapers the dashboard flagged
/// `isFeatured: true` - `isPremium` is a separate, unrelated paywall flag and
/// must never affect Trending membership. See `MockCatalog.trending()` and
/// `ExploreRemoteDatasourceImpl.getTrending()` (which sends `featured: true`
/// to the live API's `/wallpapers` feed).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MockCatalog.reset);

  test('isFeatured parses from the API feed-item shape', () {
    final featured = WallpaperModel.fromApiFeedItem(const {
      'id': 'a',
      'title': 'A',
      'category': {'id': 'c1', 'name': 'Cat', 'slug': 'cat'},
      'thumbnailUrl': 'https://x/a.jpg',
      'fullUrl': 'https://x/a.jpg',
      'resolution': '1080x1920',
      'isFeatured': true,
      'isPremium': false,
    });
    expect(featured.isFeatured, isTrue);

    final notFeatured = WallpaperModel.fromApiFeedItem(const {
      'id': 'b',
      'title': 'B',
      'category': {'id': 'c1', 'name': 'Cat', 'slug': 'cat'},
      'thumbnailUrl': 'https://x/b.jpg',
      'fullUrl': 'https://x/b.jpg',
      'resolution': '1080x1920',
      'isFeatured': false,
      'isPremium': true,
    });
    expect(notFeatured.isFeatured, isFalse);
  });

  test('isFeatured defaults safely to false when missing from the response',
      () {
    final wallpaper = WallpaperModel.fromApiFeedItem(const {
      'id': 'c',
      'title': 'C',
      'category': {'id': 'c1', 'name': 'Cat', 'slug': 'cat'},
      'thumbnailUrl': 'https://x/c.jpg',
      'fullUrl': 'https://x/c.jpg',
      'resolution': '1080x1920',
      // isFeatured intentionally omitted
    });
    expect(wallpaper.isFeatured, isFalse);
  });

  test('MockCatalog.trending() returns only isFeatured wallpapers - premium '
      'never determines membership', () async {
    final catalog = await MockCatalog.load();
    final page = catalog.trending(limit: 100);

    expect(page.items, isNotEmpty,
        reason: 'sanity check: the fixture has at least one featured row');
    for (final wallpaper in page.items) {
      expect(wallpaper.isFeatured, isTrue,
          reason: '${wallpaper.id} is in Trending but is not featured');
    }

    // The fixture is known (from Investigation) to contain isPremium rows
    // both inside and outside the featured set - confirm premium alone
    // never explains inclusion.
    final anyPremiumExcluded = catalog.wallpapers
        .where((w) => w.isPremium && !w.isFeatured)
        .isNotEmpty;
    expect(anyPremiumExcluded, isTrue,
        reason: 'sanity check: fixture has a premium-but-not-featured row '
            'that must NOT appear in trending()');
    expect(
      page.items.any((w) => w.isPremium && !w.isFeatured),
      isFalse,
    );
  });

  test('MockCatalog.trending() preserves the fixture-authored order among '
      'featured rows (no client-side re-sort)', () async {
    final catalog = await MockCatalog.load();
    final expectedOrder = catalog.wallpapers
        .where((w) => w.isFeatured)
        .map((w) => w.id)
        .toList();

    final page = catalog.trending(limit: 100);
    expect(page.items.map((w) => w.id).toList(), expectedOrder);
  });
}
