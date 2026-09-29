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

/// Even if the live backend still serves a "Cities" category row (the
/// historical-data case the redesign spec explicitly allows), the
/// Categories tab must never offer it as a selectable tile - only the 8
/// approved categories, each rendered from the dashboard's own
/// `thumbnailUrl` (a plain colour fallback when one is missing) - see
/// `category_card_cover_image_test.dart` for that image-source coverage.
const _categories = [
  CategoryEntity(id: 'c1', name: 'Nature', slug: 'nature', wallpaperCount: 4),
  CategoryEntity(id: 'c2', name: 'AMOLED', slug: 'amoled', wallpaperCount: 2),
  CategoryEntity(id: 'c3', name: 'Space', slug: 'space', wallpaperCount: 2),
  CategoryEntity(id: 'c4', name: 'Cars', slug: 'cars', wallpaperCount: 1),
  CategoryEntity(id: 'c5', name: 'Anime', slug: 'anime', wallpaperCount: 1),
  CategoryEntity(id: 'c6', name: 'Minimal', slug: 'minimal', wallpaperCount: 1),
  CategoryEntity(id: 'c7', name: 'Abstract', slug: 'abstract', wallpaperCount: 1),
  CategoryEntity(id: 'c8', name: 'Cities', slug: 'cities', wallpaperCount: 2),
  CategoryEntity(id: 'c9', name: 'Animals', slug: 'animals', wallpaperCount: 0),
];

void main() {
  setUp(() {
    di.sl.registerFactory<CategoriesBloc>(
      () => CategoriesBloc(getCategories: _FakeGetCategoriesUseCase()),
    );
  });

  tearDown(() => di.sl.reset());

  testWidgets('Cities is never rendered as a tile, even though the backend '
      'returned it - the other 8 approved categories all are', (tester) async {
    // Tall enough that all 8 (post-filter) 120px+separator tiles are
    // actually laid out - the default test viewport is too short to fit
    // more than a few.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CategoriesPage(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cities'), findsNothing);
    expect(find.text('Nature'), findsOneWidget);
    expect(find.text('AMOLED'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    expect(find.text('Cars'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Abstract'), findsOneWidget);
    expect(find.text('Animals'), findsOneWidget);

    // The Live pseudo-category always leads the tab, so the tab renders the
    // 8 approved BACKEND tiles plus that one - and still no Cities, which is
    // filtered out of the list entirely rather than just visually skipped.
    expect(find.text('Live Wallpapers'), findsOneWidget);
    // None of these fixture rows carries a `thumbnailUrl`, so every one of
    // the 9 tiles falls back to the plain colour block - proving the card
    // never crashes or blanks out with no cover image, and confirming no
    // bundled local image is ever painted for any of them (a bundled
    // `Image.asset` would appear here as `Image`; a fetched one would be
    // `CachedNetworkImage`, per `category_card_cover_image_test.dart`).
    expect(find.byType(Image), findsNothing);
  });
}

class _FakeGetCategoriesUseCase implements GetCategoriesUseCase {
  @override
  Future<Either<Failure, List<CategoryEntity>>> call(NoParams params) async =>
      const Right(_categories);
}
