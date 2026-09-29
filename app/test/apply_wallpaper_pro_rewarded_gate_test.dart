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
import 'package:creativebackground/injection.dart' as di;
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A PRO wallpaper must never apply without the user having watched a
/// rewarded ad to completion first - see
/// `_ApplySheet._showRewardedGate`/`_apply` in apply_wallpaper_page.dart.
///
/// No real ad is loaded in these widget tests (no network, no AdMob SDK
/// available), so `AdManager.instance.isRewardedReady` is always false here -
/// this deliberately exercises the "ad genuinely not ready" branch, which
/// must show a message and apply nothing rather than silently letting the
/// wallpaper through.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');
  final proWallpaper = WallpaperEntity(
    id: 'w-pro',
    title: 'PRO Wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w-pro.webp',
    fullUrl: 'https://cdn.test/w-pro.webp',
    resolution: '1080x1920',
    isPremium: true,
  );
  final freeWallpaper = WallpaperEntity(
    id: 'w-free',
    title: 'Free Wallpaper',
    category: category,
    thumbnailUrl: 'https://cdn.test/w-free.webp',
    fullUrl: 'https://cdn.test/w-free.webp',
    resolution: '1080x1920',
    isPremium: false,
  );

  late GoRouter router;
  var applyCallCount = 0;

  Future<void> pumpApp(WidgetTester tester) async {
    // Real phone viewport - the apply sheet is height-constrained, so the
    // default short test window scrolls its CTA out of the hit-test area.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const _HomeStub()),
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
    applyCallCount = 0;
    di.sl.registerFactory<ApplyWallpaperBloc>(
      () => ApplyWallpaperBloc(
        ApplyWallpaperUseCase(_CountingApplyRepository(() => applyCallCount++)),
      ),
    );
  });

  tearDown(() => di.sl.reset());

  testWidgets(
      'tapping Apply on a PRO wallpaper shows the watch-ad confirmation '
      'dialog with a Cancel option, never applying immediately',
      (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: proWallpaper));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Wallpaper'));
    await tester.pumpAndSettle();

    expect(find.text('Watch an ad to apply'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(find.text('Watch Ad'), findsOneWidget);
    expect(applyCallCount, 0,
        reason: 'the apply request must not fire until the ad is confirmed '
            'AND actually watched');
  });

  testWidgets(
      'cancelling the watch-ad dialog applies nothing and returns to the '
      'sheet', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: proWallpaper));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Wallpaper'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(applyCallCount, 0);
    expect(find.byType(_SuccessStub), findsNothing);
  });

  testWidgets(
      'confirming "Watch Ad" when no rewarded ad is actually ready shows an '
      'unavailable message and still applies nothing', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: proWallpaper));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Wallpaper'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch Ad'));
    await tester.pumpAndSettle();

    expect(
      find.text("The ad isn't ready yet. Please try again in a moment."),
      findsOneWidget,
    );
    expect(applyCallCount, 0);
    expect(find.byType(_SuccessStub), findsNothing);
  });

  testWidgets(
      'a free (non-PRO) wallpaper applies immediately with no ad dialog at '
      'all - the gate is PRO-only', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(_HomeStub));

    unawaited(showApplyWallpaperSheet(context, wallpaper: freeWallpaper));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Wallpaper'));
    await tester.pumpAndSettle();

    expect(find.text('Watch an ad to apply'), findsNothing);
    expect(applyCallCount, 1);
    expect(find.byType(_SuccessStub), findsOneWidget);
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

class _CountingApplyRepository implements ApplyWallpaperRepository {
  _CountingApplyRepository(this.onApply);
  final void Function() onApply;

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async {
    onApply();
    return const Right(true);
  }
}
