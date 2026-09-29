import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:creativebackground/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:creativebackground/features/favorites/domain/usecases/remove_favorite_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/domain/repositories/wallpaper_details_repository.dart';
import 'package:creativebackground/features/wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/bloc/wallpaper_details_bloc.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/pages/wallpaper_details_page.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Section 14's golden facts: Details never draws a design element TWICE,
/// and when it draws at all, the overlay paints strictly above the media.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  void mockChannels() {
    di.sl.registerFactory<WallpaperDetailsBloc>(
      () => WallpaperDetailsBloc(
        getDetails: GetWallpaperDetailsUseCase(
          _FakeDetailsRepository(_current!),
        ),
        addFavorite: AddFavoriteUseCase(_FakeFavoritesRepository()),
        removeFavorite: RemoveFavoriteUseCase(_FakeFavoritesRepository()),
        favoritesRepository: _FakeFavoritesRepository(),
        repository: _FakeDetailsRepository(_current!),
      ),
    );
  }

  tearDown(() => di.sl.reset());

  testWidgets(
    'a DEPTH wallpaper with BOTH layers renders the clock LIVE exactly '
    'once, with the foreground painted AFTER it so the subject occludes '
    'the design - never the frozen baked composite',
    (tester) async {
      _current = WallpaperEntity(
        id: 'w1',
        title: 'Depth with both layers',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/composite.webp',
        backgroundUrl: 'https://cdn.test/bg.webp',
        foregroundMaskUrl: 'https://cdn.test/fg.webp',
        hasForegroundMask: true,
        resolution: '1080x1920',
        width: 1080,
        height: 1920,
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 80),
        ),
      );
      mockChannels();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(id: 'w1', knownWallpaper: _current),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.byType(ClockRendererWidget),
        findsOneWidget,
        reason: 'both depth layers plus a design are present, so Details '
            'must reconstruct the design LIVE rather than paint a frozen '
            'server composite - the clock draws exactly once',
      );

      // z-order: the foreground `CachedNetworkImage` (there are two -
      // background and foreground; the foreground is added AFTER the design
      // inside `DepthLiveComposition`) must be a later element than the
      // clock, so it paints on top and occludes it - matching the native
      // `DepthCompositor.kt` order this mirrors.
      final foregroundFinder = find.byWidgetPredicate(
        (w) => w is CachedNetworkImage && w.imageUrl == 'https://cdn.test/fg.webp',
      );
    // FLUTTER_RENDERING_GUIDE §2 (DEPTH): background, foreground, clock,
    // then the foreground AGAIN at (1 - clock.depth) - the occlusion copy.
    final fgs = foregroundFinder.evaluate().toList();
    expect(fgs, hasLength(2),
        reason: 'the subject is drawn under the clock and again over it');
    final clockElement = tester.element(find.byType(ClockRendererWidget));
    expect(_paintsAfter(tester, later: clockElement, earlier: fgs.first), isTrue,
        reason: 'the first foreground sits beneath the clock');
    expect(_paintsAfter(tester, later: fgs.last, earlier: clockElement), isTrue,
        reason: 'the occlusion copy paints over the clock');
    final occlusion = tester.widget<Opacity>(find.ancestor(
      of: find.byWidget(fgs.last.widget),
      matching: find.byType(Opacity),
    ).first);
    expect(occlusion.opacity, closeTo(1 - 0.45, 1e-9),
        reason: 'depth 0 hides the clock behind the subject, 1 leaves it in front');
    },
  );

  testWidgets(
    'a DEPTH wallpaper missing the foreground layer falls back to the '
    'baked composite, so ClockRendererWidget renders ZERO times - drawing '
    'it again would duplicate the clock already baked into the pixels',
    (tester) async {
      _current = WallpaperEntity(
        id: 'w1b',
        title: 'Depth missing a layer',
        category: category,
        type: WallpaperType.depth,
        thumbnailUrl: 'https://cdn.test/thumb.webp',
        fullUrl: 'https://cdn.test/composite.webp',
        backgroundUrl: 'https://cdn.test/bg.webp',
        // No foreground - `supportsDepth` is false, so live composition
        // cannot apply and the resolver falls back to the flattened asset.
        resolution: '1080x1920',
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 80),
        ),
      );
      mockChannels();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(id: 'w1b', knownWallpaper: _current),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.byType(ClockRendererWidget),
        findsNothing,
        reason: 'supportsDepth is false (only one layer present), so '
            'resolveDetailsVisual falls back to the baked composite, which '
            'already contains the clock',
      );
    },
  );

  testWidgets(
    'a STANDARD wallpaper with an authored clock renders it EXACTLY ONCE, '
    'and the DesignOverlay paints above the wallpaper image in the stack',
    (tester) async {
      _current = WallpaperEntity(
        id: 'w2',
        title: 'Standard with clock',
        category: category,
        type: WallpaperType.normal,
        thumbnailUrl: 'https://cdn.test/thumb2.webp',
        fullUrl: 'https://cdn.test/raw.webp',
        resolution: '1080x1920',
        isDetailed: true,
        design: const StudioDesign(
          clock: ClockConfigEntity(enabled: true, sizePx: 80),
        ),
      );
      mockChannels();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WallpaperDetailsPage(id: 'w2', knownWallpaper: _current),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.byType(ClockRendererWidget),
        findsOneWidget,
        reason: 'a STANDARD preview never bakes the clock - Details must '
            'draw it live, exactly once',
      );

      // z-order: a later element in Flutter's depth-first build order is a
      // LATER Stack child, which paints on top of earlier ones. Comparing
      // the build order of the image layer against the clock layer is
      // therefore an exact proxy for paint order here.
      final imageElement = tester.element(find.byType(CachedNetworkImage).first);
      final clockElement = tester.element(find.byType(ClockRendererWidget));

      expect(
        _paintsAfter(tester, later: clockElement, earlier: imageElement),
        isTrue,
        reason: 'the design overlay must paint AFTER (on top of) the media '
            'layer, not be painted over by it',
      );
    },
  );
}

WallpaperEntity? _current;

/// True when [later] appears strictly after [earlier] in the widget tree's
/// depth-first build order - for sibling `Stack` children (which is the only
/// relationship this file uses this for), that order IS paint order: a
/// later Stack child paints on top of an earlier one.
bool _paintsAfter(
  WidgetTester tester, {
  required Element later,
  required Element earlier,
}) {
  var earlierSeen = false;
  var result = false;
  void visit(Element e) {
    if (result) return;
    if (e == earlier) earlierSeen = true;
    if (e == later && earlierSeen) result = true;
    e.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return result;
}

class _FakeDetailsRepository implements WallpaperDetailsRepository {
  _FakeDetailsRepository(this.wallpaper);
  final WallpaperEntity wallpaper;

  @override
  Future<Either<Failure, WallpaperEntity>> getWallpaperDetails(
    String idOrSlug,
  ) async =>
      Right(wallpaper);

  @override
  Future<void> recordView(String idOrSlug) async {}
}

class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Future<Either<Failure, List<WallpaperEntity>>> getFavorites() async =>
      const Right([]);

  @override
  Future<Either<Failure, Unit>> addFavorite(WallpaperEntity wallpaper) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> removeFavorite(String wallpaperId) async =>
      const Right(unit);

  @override
  bool isFavorite(String wallpaperId) => false;

  @override
  Stream<void> watchChanges() => const Stream.empty();
}
