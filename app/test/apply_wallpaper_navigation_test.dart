import 'dart:async';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/router/route_names.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/pages/apply_wallpaper_page.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Phase 11, end-to-end: driving the real apply sheet through GoRouter and
/// asserting where the user actually lands - the thing that matters, since
/// the bug was entirely about an extra screen appearing at the wrong time.
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

  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    // A real phone viewport: the apply sheet is height-constrained to a
    // fraction of the screen, and the default 800x600 test window is short
    // enough to push its CTA into the scrolled-off region.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const _HomeStub()),
        // The real app's Home tab IS `RouteNames.explore` - a live/depth
        // apply now calls `context.go(RouteNames.explore)` to return
        // directly to Home, so the test router needs this path registered
        // too (pointing at the same Home stub) for that navigation to land
        // anywhere instead of falling through to GoRouter's error page.
        GoRoute(
            path: RouteNames.explore,
            builder: (context, state) => const _HomeStub()),
        GoRoute(
            path: RouteNames.success,
            builder: (context, state) => const _SuccessStub()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pump();
  }

  setUp(() {
    di.sl.registerFactory<ApplyWallpaperBloc>(
      () => ApplyWallpaperBloc(ApplyWallpaperUseCase(_FakeApplyRepository())),
    );
  });

  tearDown(() => di.sl.reset());

  testWidgets(
      'applying a STATIC wallpaper navigates to the Done screen - it is the '
      'only confirmation, so it must still appear', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: wallpaper));
    await tester.pumpAndSettle();

    // Home is pre-selected; the sheet confirms with its own CTA.
    await tester.tap(find.text('Apply Wallpaper'));
    await tester.pumpAndSettle();

    expect(find.byType(_SuccessStub), findsOneWidget);
  });

  testWidgets(
      'applying a LIVE (clock) wallpaper does NOT navigate to the Done '
      'screen - Android\'s own picker is the confirmation, not this app\'s '
      'own Done screen - and returns straight to Home rather than leaving '
      'the user on Details/Customize waiting for the picker\'s outcome',
      (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(
      context,
      wallpaper: wallpaper,
      clockConfig: const ClockConfigEntity(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set as live wallpaper'));
    await tester.pumpAndSettle();

    expect(find.byType(_SuccessStub), findsNothing);
    // The sheet closed (it did not just hang), and we are back at Home.
    expect(find.byType(_HomeStub), findsOneWidget);
  });

  testWidgets(
      'applying a LIVE VIDEO wallpaper (no clock, no depth config at all) '
      'still shows "Set as live wallpaper" and returns to Home rather than '
      'the Done screen - this is the exact gap a video wallpaper apply used '
      'to fall through', (tester) async {
    final videoWallpaper = WallpaperEntity(
      id: 'w3',
      title: 'Video wallpaper',
      category: category,
      type: WallpaperType.live,
      thumbnailUrl: 'https://cdn.test/w3.webp',
      fullUrl: 'https://cdn.test/w3.webp',
      resolution: '1080x1920',
    );
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: videoWallpaper));
    await tester.pumpAndSettle();

    expect(find.text('Set as live wallpaper'), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);

    await tester.tap(find.text('Set as live wallpaper'));
    await tester.pumpAndSettle();

    expect(find.byType(_SuccessStub), findsNothing);
    expect(find.byType(_HomeStub), findsOneWidget);
  });

  group('the design payload that actually reaches apply', () {
    /// A designed wallpaper carrying a batteryRing - the shape the real
    /// `porshe` wallpaper has. No Porshe-specific production code exists; this
    /// is only the fixture shape.
    WallpaperEntity designedWithRing() => wallpaper.copyWith(
          remoteClockConfig: const ClockConfigEntity(),
          design: const StudioDesign(
            clock: ClockConfigEntity(),
            widgets: [StudioBatteryRing(customX: 0.8, customY: 0.13)],
          ),
        );

    testWidgets('With Design sends BOTH the clock and the batteryRing',
        (tester) async {
      _FakeApplyRepository.lastClock = null;
      _FakeApplyRepository.lastWidgets = const [];

      await pumpApp(tester);
      final context = tester.element(find.byType(_HomeStub));
      unawaited(showApplyWallpaperSheet(
        context,
        wallpaper: designedWithRing(),
        clockConfig: const ClockConfigEntity(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as live wallpaper'));
      await tester.pumpAndSettle();

      expect(_FakeApplyRepository.lastClock, isNotNull);
      expect(_FakeApplyRepository.lastWidgets, hasLength(1));
      expect(
        _FakeApplyRepository.lastWidgets.single,
        isA<StudioBatteryRing>(),
        reason: 'the ring the user previewed must reach the applied wallpaper',
      );
    });

    testWidgets('Wallpaper Only sends NEITHER the clock nor the ring',
        (tester) async {
      _FakeApplyRepository.lastClock = const ClockConfigEntity();
      _FakeApplyRepository.lastWidgets = const [StudioBatteryRing()];

      await pumpApp(tester);
      final context = tester.element(find.byType(_HomeStub));
      unawaited(showApplyWallpaperSheet(
        context,
        wallpaper: designedWithRing(),
        clockConfig: const ClockConfigEntity(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wallpaper Only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Wallpaper'));
      await tester.pumpAndSettle();

      expect(
        _FakeApplyRepository.lastClock,
        isNull,
        reason: 'the clock must not reach a Wallpaper Only apply',
      );
      expect(
        _FakeApplyRepository.lastWidgets,
        isEmpty,
        reason: 'the ring must not reach a Wallpaper Only apply either',
      );
    });
  });
}

class _HomeStub extends StatelessWidget {
  const _HomeStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

class _SuccessStub extends StatelessWidget {
  const _SuccessStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('success'));
}

class _FakeApplyRepository implements ApplyWallpaperRepository {
  /// What the last apply actually received - the whole point of the
  /// With Design / Wallpaper Only contract.
  static ClockConfigEntity? lastClock;
  static List<StudioWidget> lastWidgets = const [];

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async {
    lastClock = clockConfig;
    lastWidgets = widgets;
    return const Right(true);
  }
}
