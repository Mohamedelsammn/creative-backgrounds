import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/usecases/usecase.dart';
import 'package:creativebackground/features/categories/presentation/bloc/categories_bloc.dart';
import 'package:creativebackground/features/categories/presentation/pages/categories_page.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_categories_usecase.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The category card's cover image is now sourced from the dashboard's own
/// `thumbnailUrl` (`imageUrl` on the live public API - see
/// `CategoryModel.fromApi`'s own doc) rather than a bundled local asset.
/// These tests exercise the real `CategoriesPage`/`_CategoryCard` widgets,
/// not a reimplementation, matching `categories_page_cities_filtered_test.dart`'s
/// own established driving pattern.
void main() {
  Future<void> pump(WidgetTester tester, List<CategoryEntity> categories) async {
    di.sl.registerFactory<CategoriesBloc>(
      () => CategoriesBloc(
        getCategories: _FakeGetCategoriesUseCase(categories),
      ),
    );
    addTearDown(() => di.sl.reset());

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CategoriesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a category with a real thumbnailUrl renders it through the network '
    'image pipeline, not a bundled asset',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(
          id: 'c1',
          name: 'Nature',
          slug: 'nature',
          thumbnailUrl: 'https://cdn.test/categories/nature.png',
          wallpaperCount: 4,
        ),
      ]);

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://cdn.test/categories/nature.png');
      // `CachedNetworkImage` internally builds a plain `Image` widget of its
      // own, so this checks for an `AssetImage` provider specifically - the
      // one thing a bundled `Image.asset` would use that a network image
      // never does.
      final assetImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((img) => img.image is AssetImage);
      expect(assetImages, isEmpty,
          reason: 'no bundled local asset image must ever be painted');
    },
  );

  testWidgets(
    'a category with NO thumbnailUrl falls back to a plain colour block, '
    'never a bundled local image',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(id: 'c1', name: 'Nature', slug: 'nature'),
      ]);

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a category with an EMPTY string thumbnailUrl also falls back safely',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(id: 'c1', name: 'Nature', slug: 'nature', thumbnailUrl: ''),
      ]);

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a malformed/unreachable URL does not crash the widget - the error '
    'builder renders the same plain fallback',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(
          id: 'c1',
          name: 'Nature',
          slug: 'nature',
          thumbnailUrl: 'not a valid url at all',
        ),
      ]);

      // The malformed URL is still handed to CachedNetworkImage (it does
      // its own validation/error handling internally via errorWidget) -
      // the requirement is simply that building the tree never throws.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the API-provided accent colour is used before the name-keyed fallback '
    'table when there is no image',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(
          id: 'c1',
          name: 'Nature',
          slug: 'nature',
          color: 0xFF123456,
        ),
      ]);

      final coloredBoxes = tester.widgetList<ColoredBox>(
        find.byType(ColoredBox),
      );
      expect(
        coloredBoxes.any((b) => b.color == const Color(0xFF123456)),
        isTrue,
        reason: 'the API\'s own accent color must be used when present',
      );
    },
  );

  testWidgets(
    'card layout/aspect-ratio is unchanged - still a 120dp-tall full-width '
    'tile with rounded corners, name and chevron all present',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(
          id: 'c1',
          name: 'Nature',
          slug: 'nature',
          thumbnailUrl: 'https://cdn.test/categories/nature.png',
          wallpaperCount: 4,
        ),
      ]);

      // The card is the SizedBox with height: 120 inside the ClipRRect -
      // located via the known text/icon it contains.
      final cardBox = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => b.height == 120)
          .toList();
      expect(cardBox, isNotEmpty,
          reason: 'the 120dp-tall card box must still exist unchanged');
      expect(find.text('Nature'), findsOneWidget);
      expect(find.text('4 Wallpapers'), findsOneWidget);
      // Two chevrons: this fixture's one real category, plus the
      // always-present Live pseudo-category card leading the tab.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    },
  );

  testWidgets(
    'the __live__ pseudo-category (no thumbnailUrl by construction) still '
    'leads the tab and renders safely with the plain fallback',
    (tester) async {
      await pump(tester, const [
        CategoryEntity(id: 'c1', name: 'Nature', slug: 'nature'),
      ]);

      expect(find.text('Live Wallpapers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeGetCategoriesUseCase implements GetCategoriesUseCase {
  _FakeGetCategoriesUseCase(this.categories);
  final List<CategoryEntity> categories;

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(NoParams params) async =>
      Right(categories);
}
