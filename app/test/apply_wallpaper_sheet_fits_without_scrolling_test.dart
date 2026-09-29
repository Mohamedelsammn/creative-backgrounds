import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Apply sheet's Home/Lock/Both destinations used to stack as three
/// full-width 54px-tall buttons, which on a short/ordinary phone screen
/// (with the preview thumbnail, title, and Cancel above/below them) could
/// require the sheet's SingleChildScrollView to actually scroll to reach
/// Cancel or the last destination. Per this correction pass, Home/Lock/Both
/// render as a single horizontal row instead, and the sheet must fit an
/// ordinary phone screen (390x844 - iPhone 12/13/14 logical size, a common
/// baseline) without needing to scroll AT ALL - scrolling stays only as a
/// fallback for extreme/accessibility cases (not exercised here).
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');
  final wallpaper = WallpaperEntity(
    id: 'w1',
    title: 'Wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w1.webp',
    fullUrl: 'https://cdn.test/w1.webp',
    resolution: '1080x1920',
  );

  setUp(() {
    di.sl.registerFactory<ApplyWallpaperBloc>(
      () => ApplyWallpaperBloc(ApplyWallpaperUseCase(_FakeApplyRepository())),
    );
  });

  tearDown(() => di.sl.reset());

  Future<void> pumpSheet(
    WidgetTester tester, {
    ClockConfigEntity? clockConfig,
    WallpaperEntity? override,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showApplyWallpaperSheet(
              context,
              wallpaper: override ?? wallpaper,
              clockConfig: clockConfig,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the static-wallpaper sheet (Home/Lock/Both row) fits an ordinary '
      'phone screen with zero scroll offset available - every action is '
      'already on-screen without scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSheet(tester);

    expect(find.text('Home Screen'), findsOneWidget);
    expect(find.text('Lock Screen'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
    expect(find.text('Apply Wallpaper'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Home/Lock/Both in ONE row: compare the tiles themselves (their shared
    // Row parent lays them out at one top edge), not the label text, whose
    // baseline legitimately differs between a one-line and a two-line label.
    final tiles = find.ancestor(
      of: find.text('Home Screen'),
      matching: find.byType(InkWell),
    );
    expect(tiles, findsWidgets);
    final homeTileY = tester.getTopLeft(tiles.first).dy;
    final lockTileY = tester
        .getTopLeft(find
            .ancestor(
                of: find.text('Lock Screen'), matching: find.byType(InkWell))
            .first)
        .dy;
    final bothTileY = tester
        .getTopLeft(find
            .ancestor(of: find.text('Both'), matching: find.byType(InkWell))
            .first)
        .dy;
    expect(homeTileY, closeTo(lockTileY, 1));
    expect(homeTileY, closeTo(bothTileY, 1));

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, 0,
        reason: 'the sheet content must already fit the viewport - no '
            'scroll distance should be available on a normal phone screen');
  });

  testWidgets(
      'the live-wallpaper sheet (single "Set as live wallpaper" CTA) also '
      'fits without any scroll distance available', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSheet(tester, clockConfig: const ClockConfigEntity());

    expect(find.text('Set as live wallpaper'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, 0);
  });

  group('the With Design / Wallpaper Only selector', () {
    // `applyTarget: "ask"` plus a real authored design is the only case that
    // shows the selector. It adds a row to the sheet, so the no-scroll
    // guarantee above has to keep holding with it present.
    WallpaperEntity designed({
      StudioApplyTarget target = StudioApplyTarget.ask,
    }) =>
        wallpaper.copyWith(
          remoteClockConfig: const ClockConfigEntity(),
          design: StudioDesign(
            clock: const ClockConfigEntity(),
            applyTarget: target,
          ),
        );

    testWidgets('is shown for a designed wallpaper whose dashboard asks',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSheet(
        tester,
        override: designed(),
        clockConfig: const ClockConfigEntity(),
      );

      expect(find.text('With Design'), findsOneWidget);
      expect(find.text('Wallpaper Only'), findsOneWidget);
    });

    testWidgets('the sheet still fits with the selector present',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSheet(
        tester,
        override: designed(),
        clockConfig: const ClockConfigEntity(),
      );

      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.maxScrollExtent, 0,
          reason: 'the extra design row must not push the sheet into '
              'needing a scroll');
    });

    testWidgets('is NOT shown for a wallpaper with no authored design',
        (tester) async {
      await pumpSheet(tester, clockConfig: const ClockConfigEntity());
      expect(find.text('With Design'), findsNothing);
      expect(find.text('Wallpaper Only'), findsNothing);
    });

    testWidgets('is NOT shown when the dashboard already decided',
        (tester) async {
      for (final target in [
        StudioApplyTarget.withDesign,
        StudioApplyTarget.wallpaperOnly,
      ]) {
        // A fresh pump per case: the sheet is a route, so re-opening it in the
        // same widget tree would stack a second one.
        await pumpSheet(
          tester,
          override: designed(target: target),
          clockConfig: const ClockConfigEntity(),
        );
        expect(find.text('With Design'), findsNothing,
            reason: 'applyTarget $target must not prompt');
        expect(find.text('Wallpaper Only'), findsNothing,
            reason: 'applyTarget $target must not prompt');
      }
    });

    testWidgets(
        'picking Wallpaper Only switches the sheet back to Home/Lock/Both',
        (tester) async {
      // The real consequence of the choice: with the clock suppressed the
      // wallpaper is no longer a live apply, so the static destinations
      // return in place of the single live CTA.
      await pumpSheet(
        tester,
        override: designed(),
        clockConfig: const ClockConfigEntity(),
      );
      expect(find.text('Set as live wallpaper'), findsOneWidget);
      expect(find.text('Home Screen'), findsNothing);

      await tester.tap(find.text('Wallpaper Only'));
      await tester.pumpAndSettle();

      expect(find.text('Set as live wallpaper'), findsNothing);
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Lock Screen'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
    });

    testWidgets('picking With Design again restores the live CTA',
        (tester) async {
      await pumpSheet(
        tester,
        override: designed(),
        clockConfig: const ClockConfigEntity(),
      );
      await tester.tap(find.text('Wallpaper Only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('With Design'));
      await tester.pumpAndSettle();

      expect(find.text('Set as live wallpaper'), findsOneWidget);
    });

  });
}

class _FakeApplyRepository implements ApplyWallpaperRepository {
  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async =>
      const Right(true);
}