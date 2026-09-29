import 'dart:io';

import 'package:creativebackground/features/categories/domain/live_category.dart';
import 'package:creativebackground/features/categories/presentation/pages/categories_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Category cover art now comes from the backend
/// (`CategoryEntity.thumbnailUrl`, sourced from the public API's
/// `coverThumbnailUrl`/`iconUrl`) - not from a bundled local asset map. This
/// file used to validate that map (`kCategoryCoverAssets`); it is now a
/// packaging/contract guard that the removal actually happened and stays
/// removed, so a future change cannot silently reintroduce all nine ~2-3 MB
/// category cover PNGs into the shipped bundle.
void main() {
  /// The exact filenames that WERE category-only cover art, keyed by their
  /// old path under `assets/images/`. Any one of these reappearing means the
  /// bundle grew back by the same ~18 MB this removal was meant to save.
  const removedCategoryAssetPaths = {
    'assets/images/live.png',
    'assets/images/nature.png',
    'assets/images/amoled.png',
    'assets/images/space.png',
    'assets/images/Cars.png',
    'assets/images/Anime.png',
    'assets/images/minimal.png',
    'assets/images/abstract.png',
    'assets/images/animals.png',
  };

  test('none of the removed category cover files exist on disk', () {
    for (final path in removedCategoryAssetPaths) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path was removed as category-only cover art and must not '
            'be re-added - the dashboard is the sole source of category '
            'art now',
      );
    }
  });

  test(
    'no local slug-to-asset-path mapping exists anymore - the source code '
    'itself has no such map to fall back to',
    () {
      final source = File(
        'lib/features/categories/presentation/pages/categories_page.dart',
      ).readAsStringSync();
      expect(
        source.contains('kCategoryCoverAssets'),
        isFalse,
        reason: 'a local category-cover asset map must not be reintroduced',
      );
      expect(
        source.contains('Image.asset'),
        isFalse,
        reason: 'the category card must not paint any bundled local image '
            '- only the network `thumbnailUrl` or a plain colour fallback',
      );
    },
  );

  test(
    'the approved-category slug allow-list is unchanged - the SAME 8 '
    'backend slugs, now decoupled from any asset mapping',
    () {
      expect(kApprovedCategorySlugs, {
        'nature',
        'amoled',
        'space',
        'cars',
        'anime',
        'minimal',
        'abstract',
        'animals',
      });
      expect(kApprovedCategorySlugs.contains('cities'), isFalse);
      expect(
        kApprovedCategorySlugs.contains(LiveCategory.slug),
        isFalse,
        reason: 'Live is prepended separately, not part of the backend '
            'allow-list',
      );
    },
  );

  test('assets/images/ still bundles app_logo.png - only category-only '
      'covers were removed, nothing else in that directory', () {
    expect(
      File('assets/images/app_logo.png').existsSync(),
      isTrue,
      reason: 'unrelated to categories - must never have been touched',
    );
  });
}
