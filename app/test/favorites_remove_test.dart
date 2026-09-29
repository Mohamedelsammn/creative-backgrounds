import 'dart:async';

import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:creativebackground/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:creativebackground/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:creativebackground/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:creativebackground/features/favorites/presentation/pages/favorites_page.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// End-to-end behavioural test for removing a favorite directly from the
/// Favorites grid - no navigation to Details, no long-press confirm sheet.
///
/// Drives the real [FavoritesPage] + real [FavoritesBloc] against a fake
/// [FavoritesRepository], because the point of this test is to prove the
/// actual widget the user taps dispatches the actual event that actually
/// removes the item and updates the actual list - a test that only checked
/// `FavoritesBloc` in isolation would miss whether the icon is wired up at
/// all, which is exactly the gap the bug report described.
void main() {
  const catA = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(
    String id, {
    bool premium = false,
    WallpaperType type = WallpaperType.normal,
  }) =>
      WallpaperEntity(
        id: id,
        title: 'Wallpaper $id',
        category: catA,
        type: type,
        thumbnailUrl: 'https://cdn.test/$id.webp',
        fullUrl: 'https://cdn.test/$id.webp',
        resolution: '1080x1920',
        isPremium: premium,
      );

  late _FakeFavoritesRepository repo;

  setUpAll(() {
    // Disables the package's internal debounce timer, which otherwise
    // outlives a widget test that mounts a live/video card and trips
    // flutter_test's "no pending timers" invariant.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() {
    repo = _FakeFavoritesRepository();
    di.sl.registerFactory<FavoritesBloc>(
      () => FavoritesBloc(
        getFavorites: GetFavoritesUseCase(repo),
        removeFavorite: RemoveFavoriteUseCase(repo),
        repository: repo,
      ),
    );
  });

  tearDown(() {
    di.sl.reset();
  });

  Future<void> pumpFavorites(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FavoritesPage(),
    ));
    // Let FavoritesFetchRequested resolve.
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping the favorite icon on a card removes it immediately, with no '
      'navigation to Details', (tester) async {
    repo.seed([wallpaper('a'), wallpaper('b')]);

    await pumpFavorites(tester);

    expect(find.text('Wallpaper a'), findsOneWidget);
    expect(find.text('Wallpaper b'), findsOneWidget);

    // Tap the favorite (remove) icon on the first card.
    final removeIcon = find.byIcon(Icons.favorite).first;
    await tester.tap(removeIcon);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper a'), findsNothing);
    expect(find.text('Wallpaper b'), findsOneWidget);
    // Still on the Favorites page - no push to Details occurred.
    expect(find.byType(FavoritesPage), findsOneWidget);
  });

  testWidgets(
      'removing the last favorite transitions to the empty state, not a '
      'blank or broken grid', (tester) async {
    repo.seed([wallpaper('only')]);

    await pumpFavorites(tester);
    expect(find.text('Wallpaper only'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper only'), findsNothing);
    // EmptyStateView renders `noFavorites` / `noFavoritesSubtitle`; the exact
    // localized copy is covered elsewhere, so this asserts the empty state
    // actually appeared rather than an empty grid or a stuck loading spinner.
    expect(find.text('No favorites yet'), findsOneWidget);
  });

  testWidgets(
      'the empty state does not permit a scroll/overscroll gesture - a '
      'CustomScrollView around it, even with no scrollable content, still '
      'let the page rubber-band on drag', (tester) async {
    repo.seed(const []);

    await pumpFavorites(tester);
    expect(find.text('No favorites yet'), findsOneWidget);

    // CustomScrollView renders a Scrollable widget even when its content is
    // SliverFillRemaining; the fixed non-scrolling layout must not.
    expect(find.byType(Scrollable), findsNothing,
        reason: 'the empty Favorites page must be a fixed layout, not a '
            'scroll view with no real content to scroll');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a premium favorite still exposes a working remove icon',
      (tester) async {
    // Guards the exact bug class this feature is prone to: the PRO badge and
    // the remove icon both live in the card's top area, and an earlier draft
    // of this fix placed them at the same corner.
    repo.seed([wallpaper('premium-1', premium: true)]);

    await pumpFavorites(tester);
    expect(find.text('PRO'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper premium-1'), findsNothing);
  });

  testWidgets(
      'the remove icon sits at the top-left of the card, never underneath '
      'the PRO badge or the title', (tester) async {
    repo.seed([wallpaper('a', premium: true)]);
    await pumpFavorites(tester);

    final positioned = tester.widget<Positioned>(
      find.ancestor(
        of: find.byIcon(Icons.favorite),
        matching: find.byType(Positioned),
      ),
    );

    expect(positioned.left, isNotNull,
        reason: 'must be anchored from the left edge, per the design');
    expect(positioned.right, isNull,
        reason: 'must not also be anchored from the right, where PRO lives');
    // True top-left, matching every other corner badge's own offset - it
    // must not float lower than that "waiting" for a badge that, for most
    // favorites (no depth/live type), is never actually there.
    expect(positioned.top, 12);
    expect(positioned.left, 12);
  });

  testWidgets('a live-type favorite still exposes a working remove icon '
      'without colliding with the LIVE type badge', (tester) async {
    repo.seed([wallpaper('live-1', type: WallpaperType.live)]);
    await pumpFavorites(tester);

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pumpAndSettle();

    expect(find.text('Wallpaper live-1'), findsNothing);
  });

  testWidgets('the removed wallpaper is actually gone from the repository, '
      'not just hidden in the UI', (tester) async {
    repo.seed([wallpaper('a'), wallpaper('b')]);
    await pumpFavorites(tester);

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pumpAndSettle();

    expect(repo.currentIds, ['b']);
  });
}

/// In-memory fake standing in for Hive-backed storage: a real list, a real
/// remove, and a real change stream - the same contract
/// `FavoritesLocalDatasource`/`FavoritesRepositoryImpl` provide.
class _FakeFavoritesRepository implements FavoritesRepository {
  final List<WallpaperEntity> _items = [];
  final _controller = StreamController<void>.broadcast();

  void seed(List<WallpaperEntity> items) => _items.addAll(items);

  List<String> get currentIds => _items.map((w) => w.id).toList();

  @override
  Future<Either<Failure, List<WallpaperEntity>>> getFavorites() async =>
      Right(List.of(_items));

  @override
  Future<Either<Failure, Unit>> addFavorite(WallpaperEntity wallpaper) async {
    _items.add(wallpaper);
    _controller.add(null);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeFavorite(String wallpaperId) async {
    _items.removeWhere((w) => w.id == wallpaperId);
    _controller.add(null);
    return const Right(unit);
  }

  @override
  bool isFavorite(String wallpaperId) =>
      _items.any((w) => w.id == wallpaperId);

  @override
  Stream<void> watchChanges() => _controller.stream;
}
