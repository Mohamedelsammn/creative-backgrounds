import 'package:creativebackground/core/fixtures/mock_catalog.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 1: the Homepage "Depths & Wallpapers" section and its View All must
/// show ONLY depth-type wallpapers - never normal, live, or any other type
/// mixed in. This exercises the fixture-backed path (`MockCatalog`), which
/// parses through the same production model as the live API, so a mapping
/// regression here would also affect the real backend path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => MockCatalog.reset());

  test('depthWallpapers returns only depth-type items, never live or normal',
      () async {
    final catalog = await MockCatalog.load();
    final page = catalog.depthWallpapers(limit: 100);

    expect(page.items, isNotEmpty,
        reason: 'fixture must contain at least one depth wallpaper for this '
            'test to be meaningful');
    for (final w in page.items) {
      expect(WallpaperType.fromWire(w.type), WallpaperType.depth);
    }
  });

  test('depthWallpapers never returns a live (video) wallpaper', () async {
    final catalog = await MockCatalog.load();
    final page = catalog.depthWallpapers(limit: 100);

    expect(
      page.items.where((w) => WallpaperType.fromWire(w.type) == WallpaperType.live),
      isEmpty,
    );
  });

  test('depthWallpapers respects an optional category filter', () async {
    final catalog = await MockCatalog.load();
    final all = catalog.depthWallpapers(limit: 100);
    if (all.items.isEmpty) return;

    final targetSlug = all.items.first.category.slug;
    if (targetSlug.isEmpty) return;

    final filtered = catalog.depthWallpapers(limit: 100, categorySlug: targetSlug);
    expect(filtered.items, isNotEmpty);
    for (final w in filtered.items) {
      expect(w.category.slug, targetSlug);
    }
  });
}
