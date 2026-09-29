import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/pagination/paginated.dart';
import 'package:creativebackground/core/theme/app_colors.dart';
import 'package:creativebackground/features/categories/presentation/bloc/category_details_bloc.dart';
import 'package:creativebackground/features/categories/presentation/pages/category_details_page.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/core/usecases/usecase.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_category_wallpapers_usecase.dart';
import 'package:creativebackground/features/explore/domain/usecases/get_live_wallpapers_usecase.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Category Details previously rendered with NO `Scaffold`/`Material`
/// ancestor at all (the route pushed it directly, and the page itself went
/// straight to `SafeArea(child: Column(...))`), which produced a black
/// default canvas and Flutter's debug "missing Material" text-underline
/// fallback - the black background + yellow-underlined text the bug report
/// showed. Fixed by wrapping the page in its own light `Scaffold`. This
/// test asserts the fix: a real `Scaffold` with the app's light background
/// exists, and the header text renders in the app's normal (non-debug)
/// styles.
void main() {
  const category = CategoryEntity(
    id: 'cat-1',
    name: 'Nature',
    slug: 'nature',
    wallpaperCount: 9,
  );

  setUp(() {
    di.sl.registerFactory<CategoryDetailsBloc>(
      () => CategoryDetailsBloc(
        getWallpapers: _FakeGetCategoryWallpapersUseCase(),
        getLiveWallpapers: _UnusedGetLiveWallpapersUseCase(),
      ),
    );
  });

  tearDown(() => di.sl.reset());

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/categories/nature',
      routes: [
        GoRoute(
          path: '/categories/:slug',
          builder: (context, state) => CategoryDetailsPage(
            slug: state.pathParameters['slug']!,
            knownCategory: category,
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('has a real Scaffold with the app light background - never a '
      'bare black canvas with no Material ancestor', (tester) async {
    await pumpPage(tester);

    final scaffoldFinder = find.byType(Scaffold);
    expect(scaffoldFinder, findsOneWidget,
        reason: 'the route must provide its own Scaffold/Material ancestor '
            '- it is pushed outside MainShell, which is the only other '
            'place one would come from');
    final scaffold = tester.widget<Scaffold>(scaffoldFinder);
    expect(scaffold.backgroundColor, AppColors.background,
        reason: 'must be the app\'s light background, not black/null');
    expect(scaffold.backgroundColor, isNot(Colors.black));
  });

  testWidgets('shows the category name and wallpaper count using the '
      'app\'s normal text styles, not a debug fallback', (tester) async {
    await pumpPage(tester);

    expect(find.text('Nature'), findsOneWidget);
    expect(find.text('9 Wallpapers'), findsOneWidget);

    final nameText = tester.widget<Text>(find.text('Nature'));
    // Flutter's "missing Material ancestor" debug fallback paints a
    // canary yellow underline `TextDecoration` - the exact defect the bug
    // report's screenshot showed. A correctly-Scaffold-wrapped Text never
    // has one.
    expect(nameText.style?.decoration, isNot(TextDecoration.underline));
  });
}

class _FakeGetCategoryWallpapersUseCase implements GetCategoryWallpapersUseCase {
  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
    CategoryWallpapersParams params,
  ) async =>
      const Right(Paginated.empty());
}

/// Never invoked by these tests (they only open REAL category slugs), but
/// CategoryDetailsBloc now requires it for the "Live Wallpapers"
/// pseudo-category - see LiveCategory.
class _UnusedGetLiveWallpapersUseCase implements GetLiveWallpapersUseCase {
  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
    PageParams params,
  ) async =>
      const Right(Paginated.empty());
}
