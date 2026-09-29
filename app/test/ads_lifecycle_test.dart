import 'dart:io';

import 'package:creativebackground/channels/wallpaper_channel.dart';
import 'package:creativebackground/core/ads/ad_manager.dart';
import 'package:creativebackground/core/ads/ad_show_policy.dart';
import 'package:creativebackground/core/ads/adaptive_banner_manager.dart';
import 'package:creativebackground/core/error/failures.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/repositories/apply_wallpaper_repository.dart';
import 'package:creativebackground/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart';
import 'package:creativebackground/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/depth/domain/entities/depth_config_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ad lifecycle rules: interstitial on every third SUCCESSFUL apply, App Open
/// timing (Splash never waits, resume threshold, expiry), one full-screen ad
/// at a time, and the banner's one-shot retry when consent arrives late.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const category = CategoryEntity(id: 'c', name: 'Nature');
  WallpaperEntity wallpaper(WallpaperType type) => WallpaperEntity(
        id: 'w',
        title: 'w',
        category: category,
        type: type,
        thumbnailUrl: 'https://cdn.test/t.webp',
        fullUrl: 'https://cdn.test/f.webp',
        resolution: '1080x1920',
      );

  group('1-4 · interstitial after successful Apply', () {
    test('every third successful apply is eligible: #3, #6, #9', () {
      final c = InterstitialApplyCounter();
      final eligible = [for (var i = 1; i <= 9; i++) c.recordSuccessfulApply()];
      expect(eligible, [false, false, true, false, false, true, false, false, true]);
    });

    Future<int> countFor(Either<Failure, bool> result, WallpaperType type) async {
      var calls = 0;
      final bloc = ApplyWallpaperBloc(
        ApplyWallpaperUseCase(_FakeRepo(result)),
        onStaticApplied: () => calls++,
      );
      bloc.add(ApplyWallpaperRequested(
        wallpaper: wallpaper(type),
        destination: ApplyDestination.homeScreen,
      ));
      await bloc.stream.firstWhere((s) => s is ApplyWallpaperSuccess || s is ApplyWallpaperError);
      await bloc.close();
      return calls;
    }

    test('a successful static apply is counted exactly once', () async {
      expect(await countFor(const Right(true), WallpaperType.normal), 1);
    });

    test('a failed apply is never counted', () async {
      expect(await countFor(const Left(WallpaperApplyFailure()), WallpaperType.normal), 0);
    });

    test('a live apply is not counted when only the picker opened', () async {
      // Counted later, when the picker reports it was set (MainShell).
      expect(await countFor(const Right(true), WallpaperType.live), 0);
    });

    test('the shell counts a live apply only on the "applied" outcome', () {
      final src = File('lib/core/router/main_shell.dart').readAsStringSync();
      expect(src, contains('outcome == LiveWallpaperApplyOutcome.applied'));
      expect(src, contains('AdManager.instance.onWallpaperApplied()'));
    });

    test('an unavailable interstitial never blocks: returns immediately', () {
      final ads = AdManager.forTesting()..debugSkipConsentForTests();
      final sw = Stopwatch()..start();
      ads.onWallpaperApplied();
      ads.onWallpaperApplied();
      final eligible = ads.onWallpaperApplied();
      sw.stop();
      expect(eligible, isTrue, reason: 'apply #3 attempts the interstitial');
      expect(ads.successfulApplies, 3);
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'synchronous, never awaits an ad');
    });
  });

  group('5-8 · App Open timing', () {
    test('cannot show before it is ready', () async {
      final ads = AdManager.forTesting()..debugSkipConsentForTests();
      expect(ads.isAppOpenReady, isFalse);
      expect(await ads.showAppOpenIfAvailable(), isFalse);
    });

    test('Splash never waits: onHomeReady returns synchronously', () {
      final ads = AdManager.forTesting()..debugSkipConsentForTests();
      final sw = Stopwatch()..start();
      ads.onHomeReady();
      expect(sw.elapsedMilliseconds, lessThan(50));
      final splash = File('lib/features/splash/presentation/pages/splash_page.dart').readAsStringSync();
      expect(splash, isNot(contains('await AdManager')), reason: 'Splash must not await ads');
    });

    test('resume shows only after >= 30 s in the background, once', () {
      final p = AppOpenPolicy();
      final t0 = DateTime(2026, 9, 29, 12);
      p.onBackgrounded(t0);
      expect(p.shouldShowOnResume(t0.add(const Duration(seconds: 10))), isFalse,
          reason: 'a quick app switch never shows');
      p.onBackgrounded(t0);
      expect(p.shouldShowOnResume(t0.add(const Duration(seconds: 31))), isTrue);
      expect(p.shouldShowOnResume(t0.add(const Duration(seconds: 32))), isFalse,
          reason: 'a duplicate resume callback never shows twice');
    });

    test('duplicate pause callbacks keep the first background moment', () {
      final p = AppOpenPolicy();
      final t0 = DateTime(2026, 9, 29, 12);
      p.onBackgrounded(t0);
      p.onBackgrounded(t0.add(const Duration(seconds: 25)));
      expect(p.shouldShowOnResume(t0.add(const Duration(seconds: 30))), isTrue);
    });

    test('returning from the Apply wallpaper picker never shows', () {
      final p = AppOpenPolicy();
      final t0 = DateTime(2026, 9, 29, 12);
      p.suppressNextResume();
      p.onBackgrounded(t0);
      expect(p.shouldShowOnResume(t0.add(const Duration(minutes: 5))), isFalse);
    });

    test('an App Open expires four hours after loading', () {
      final p = AppOpenPolicy();
      final loaded = DateTime(2026, 9, 29, 8);
      expect(p.isExpired(loaded, loaded.add(const Duration(hours: 3, minutes: 59))), isFalse);
      expect(p.isExpired(loaded, loaded.add(const Duration(hours: 4))), isTrue);
    });

    test('a late first load may show only within the cold-start window', () {
      final p = AppOpenPolicy();
      final home = DateTime(2026, 9, 29, 12);
      expect(p.withinColdStartWindow(home, home.add(const Duration(seconds: 5))), isTrue);
      expect(p.withinColdStartWindow(home, home.add(const Duration(seconds: 20))), isFalse);
    });
  });

  group('9 · one full-screen ad at a time', () {
    test('App Open cannot show over Interstitial or Rewarded', () {
      final g = FullScreenAdGate();
      expect(g.tryAcquire(FullScreenAdFormat.interstitial), isTrue);
      expect(g.tryAcquire(FullScreenAdFormat.appOpen), isFalse);
      g.release(FullScreenAdFormat.interstitial);
      expect(g.tryAcquire(FullScreenAdFormat.rewarded), isTrue);
      expect(g.tryAcquire(FullScreenAdFormat.appOpen), isFalse);
      expect(g.tryAcquire(FullScreenAdFormat.interstitial), isFalse,
          reason: 'Interstitial cannot show over Rewarded');
    });

    test('no duplicate show, and a stray release cannot free another claim', () {
      final g = FullScreenAdGate();
      expect(g.tryAcquire(FullScreenAdFormat.rewarded), isTrue);
      expect(g.tryAcquire(FullScreenAdFormat.rewarded), isFalse);
      g.release(FullScreenAdFormat.appOpen);
      expect(g.isShowing, isTrue);
      g.release(FullScreenAdFormat.rewarded);
      expect(g.isShowing, isFalse);
    });

    test('a pause caused by our own full-screen ad is not a real background', () {
      final src = File('lib/core/ads/ad_manager.dart').readAsStringSync();
      expect(src, contains('if (_gate.isShowing) return;'));
    });
  });

  group('10 · banner retries once when consent allows ads later', () {
    test('an ineligible banner loads again when ads start, without a loop', () {
      final src = File('lib/core/ads/adaptive_banner_manager.dart').readAsStringSync();
      expect(src, contains('AdManager.instance.whenAdsStarted.then'));
      expect(src, contains('if (!_waitingForAds)'), reason: 'registers at most once');
    });

    test('whenAdsStarted completes once ads become permitted', () async {
      final ads = AdManager.forTesting()..debugSkipConsentForTests();
      var fired = false;
      ads.whenAdsStarted.then((_) => fired = true);
      await Future<void>.delayed(Duration.zero);
      expect(fired, isFalse);
      ads.debugMarkAdsStartedForTests();
      await Future<void>.delayed(Duration.zero);
      expect(fired, isTrue);
    });

    testWidgets('one unit: requests go one at a time, never in a burst', (tester) async {
      final pacer = AdUnitRequestPacer();
      final order = <int>[];
      final turns = <AdUnitTurn>[];
      for (var i = 0; i < 3; i++) {
        pacer.acquire('feed').then((t) {
          order.add(i);
          turns.add(t);
        });
      }
      await tester.pump();
      expect(order, [0], reason: 'the other slots wait for the first request');
      turns[0].release(failed: false);
      await tester.pump();
      expect(order, [0, 1], reason: 'after a fill the next goes immediately');
      turns[1].release(failed: false);
      await tester.pump();
      expect(order, [0, 1, 2]);
      turns[2].release(failed: false);
      expect(pacer.isBusy('feed'), isFalse);
    });

    testWidgets('after a failure the next request on that unit waits 30 s', (tester) async {
      final pacer = AdUnitRequestPacer();
      AdUnitTurn? first;
      pacer.acquire('feed').then((t) => first = t);
      var second = false;
      pacer.acquire('feed').then((_) => second = true);
      await tester.pump();
      first!.release(failed: true);
      first!.release(failed: true); // a duplicate callback is ignored
      await tester.pump(const Duration(seconds: 29));
      expect(second, isFalse, reason: 'no request while the unit backs off');
      await tester.pump(const Duration(seconds: 2));
      expect(second, isTrue);
    });

    testWidgets('different units never block each other', (tester) async {
      final pacer = AdUnitRequestPacer();
      pacer.acquire('feed');
      var bottom = false;
      pacer.acquire('bottom').then((_) => bottom = true);
      await tester.pump();
      expect(bottom, isTrue);
    });

    test('every banner shares one pacer and frees its turn on dispose', () {
      final src = File('lib/core/ads/adaptive_banner_manager.dart').readAsStringSync();
      expect(src, contains('static final AdUnitRequestPacer _pacer'));
      expect(src, contains('await _pacer.acquire(adUnitId)'));
      expect(RegExp(r'_releaseUnitTurn\(failed: true\)').allMatches(src).length, 1,
          reason: 'only onAdFailedToLoad starts a backoff');
    });

    test('a banner never requests an ad without consent', () async {
      final manager = AdaptiveBannerManager('test-unit');
      await manager.load(360);
      expect(manager.ad, isNull);
      manager.dispose();
    });
  });

  group('11 · Rewarded unchanged', () {
    test('no ad ready: the unlock is refused, never granted', () async {
      final ads = AdManager.forTesting()..debugSkipConsentForTests();
      expect(ads.isRewardedReady, isFalse);
      expect(await ads.showRewardedAdForUnlock(), isFalse);
    });
  });
}

class _FakeRepo implements ApplyWallpaperRepository {
  _FakeRepo(this.result);
  final Either<Failure, bool> result;

  @override
  Future<Either<Failure, bool>> apply({
    required WallpaperEntity wallpaper,
    required ApplyDestination destination,
    ClockConfigEntity? clockConfig,
    DepthConfigEntity? depthConfig,
    List<StudioWidget> widgets = const [],
    StudioDateWidget? dateWidget,
  }) async =>
      result;
}
