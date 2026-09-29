import 'dart:io';

import 'package:creativebackground/core/ads/ad_manager.dart';
import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/core/storage/hive_storage.dart';
import 'package:creativebackground/core/storage/storage_keys.dart';
import 'package:creativebackground/features/adblock/data/services/ad_block_detection_service.dart';
import 'package:creativebackground/features/adblock/data/services/ad_integrity_service.dart';
import 'package:creativebackground/features/adblock/domain/entities/ad_integrity_result.dart';
import 'package:creativebackground/features/adblock/presentation/ad_integrity_gate.dart';
import 'package:creativebackground/features/adblock/presentation/pages/ad_blocking_detected_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The FULL integrity check (Prompt AI's algorithm): ad probe + the
/// cross-session NETWORK_ERROR streak + VPN corroboration, and the gate that
/// shows the ads-blocked screen after Home. The governing rule is the
/// reference's: only NETWORK_ERROR (code 2) on every ad, repeated across 3
/// sessions while general connectivity is healthy, or a named ad-blocking
/// Private DNS, is evidence. No Fill and every other error never are.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const loaded = AdProbeOutcome(
    sdkInitialized: true,
    bannerLoaded: true,
    interstitialLoaded: true,
    appOpenLoaded: true,
  );
  AdProbeOutcome allFailed(AdFailureKind kind) => AdProbeOutcome(
    sdkInitialized: true,
    bannerLoaded: false,
    interstitialLoaded: false,
    appOpenLoaded: false,
    bannerFailureKind: kind,
    interstitialFailureKind: kind,
    appOpenFailureKind: kind,
  );

  setUp(() async {
    Hive.init('.dart_tool/test_hive_integrity_full');
    await Hive.openBox(HiveBoxes.settings);
    await Hive.box(HiveBoxes.settings).clear();
    // Not the first run, so the reference's one-time probe retry is skipped.
    await Hive.box(HiveBoxes.settings).put(StorageKeys.adIntegrityFirstRun, true);
  });

  tearDown(() async {
    await Hive.box(HiveBoxes.settings).clear();
    await Hive.close();
  });

  int streak() =>
      Hive.box(HiveBoxes.settings).get(StorageKeys.adNetworkBlockStreak) as int? ?? 0;

  AdIntegrityService build({
    required AdProbeOutcome probe,
    bool connectivity = true,
    bool? vpn = false,
    String? dns,
  }) => AdIntegrityService(
    adBlockService: _FakeSignals(vpn: vpn, dns: dns),
    storage: HiveStorage(),
    probe: () async => probe,
    connectivityCheck: () async => connectivity,
  );

  group('classification of AdMob error codes', () {
    test('3 = No Fill, 2 = network error, anything else is ambiguous', () {
      expect(classifyAdErrorCode(3), AdFailureKind.noFill);
      expect(classifyAdErrorCode(2), AdFailureKind.networkError);
      expect(classifyAdErrorCode(1), AdFailureKind.other, reason: 'invalid request');
      expect(classifyAdErrorCode(0), AdFailureKind.other, reason: 'internal error');
      expect(classifyAdErrorCode(null), AdFailureKind.none);
    });
  });

  group('1 · normal internet, no blocker', () {
    test('ads load -> granted, streak stays 0', () async {
      final r = await build(probe: loaded).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
      expect(streak(), 0);
    });
  });

  group('2 · confirmed blocker', () {
    test('NETWORK_ERROR on every ad with healthy connectivity blocks only on '
        'the 3rd consecutive session', () async {
      final s = build(probe: allFailed(AdFailureKind.networkError));
      expect((await s.runIntegrityCheck()).isBlocked, isFalse);
      expect((await s.runIntegrityCheck()).isBlocked, isFalse);
      final third = await s.runIntegrityCheck();
      expect(third.isBlocked, isTrue);
      expect(third.reason, AdBlockReason.adsFailedToLoad);
      expect(streak(), 3);
    });

    test('a named ad-blocking Private DNS blocks immediately', () async {
      final r = await build(probe: loaded, dns: 'abc.dns.nextdns.io').runIntegrityCheck();
      expect(r.reason, AdBlockReason.dnsFilterDetected);
    });
  });

  group('3-4 · offline / DNS timeout is never ad blocking', () {
    test('ads fail with NETWORK_ERROR but google.com does not resolve -> '
        'granted and the streak resets', () async {
      await Hive.box(HiveBoxes.settings).put(StorageKeys.adNetworkBlockStreak, 2);
      final r = await build(
        probe: allFailed(AdFailureKind.networkError),
        connectivity: false,
      ).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
      expect(streak(), 0);
    });

    test('a probe that timed out is ambiguous -> granted', () async {
      final r = await build(probe: allFailed(AdFailureKind.other)).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
    });
  });

  group('5-6 · AdMob failures are not ad blocking', () {
    test('No Fill on every ad -> granted, even with a streak of 2 behind it',
        () async {
      await Hive.box(HiveBoxes.settings).put(StorageKeys.adNetworkBlockStreak, 2);
      final r = await build(probe: allFailed(AdFailureKind.noFill)).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
      expect(streak(), 0, reason: 'No Fill proves the ad server was reached');
    });

    test('a mixed / partial failure -> granted, streak reset', () async {
      await Hive.box(HiveBoxes.settings).put(StorageKeys.adNetworkBlockStreak, 2);
      const mixed = AdProbeOutcome(
        sdkInitialized: true,
        bannerLoaded: false,
        interstitialLoaded: false,
        appOpenLoaded: false,
        bannerFailureKind: AdFailureKind.networkError,
        interstitialFailureKind: AdFailureKind.noFill,
        appOpenFailureKind: AdFailureKind.networkError,
      );
      final r = await build(probe: mixed).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
      expect(streak(), 0);
    });

    test('one ad loaded -> granted', () async {
      const one = AdProbeOutcome(
        sdkInitialized: true,
        bannerLoaded: false,
        interstitialLoaded: true,
        appOpenLoaded: false,
        bannerFailureKind: AdFailureKind.networkError,
        appOpenFailureKind: AdFailureKind.networkError,
      );
      expect((await build(probe: one).runIntegrityCheck()).isBlocked, isFalse);
    });
  });

  group('7 · VPN needs evidence', () {
    test('an active VPN with ads loading -> granted', () async {
      final r = await build(probe: loaded, vpn: true).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
    });

    test('an active VPN with ads No-Filling -> granted', () async {
      final r = await build(probe: allFailed(AdFailureKind.noFill), vpn: true)
          .runIntegrityCheck();
      expect(r.isBlocked, isFalse);
    });

    test('a VPN AND every ad failing at the network level -> blocked', () async {
      final r = await build(probe: allFailed(AdFailureKind.networkError), vpn: true)
          .runIntegrityCheck();
      expect(r.reason, AdBlockReason.vpnDetected);
    });
  });

  group('8 · Private DNS follows the reference list', () {
    test('the list is exactly Prompt AI\'s six providers', () {
      expect(AdIntegrityService.knownAdBlockDnsPatterns,
          ['adguard', 'nextdns', 'controld', 'mullvad', 'blahdns', 'rethinkdns']);
    });

    for (final host in const ['dns.google', 'one.one.one.one', 'dns.quad9.net',
        'doh.cleanbrowsing.org']) {
      test('$host (not an ad blocker) -> granted', () async {
        final r = await build(probe: loaded, dns: host).runIntegrityCheck();
        expect(r.isBlocked, isFalse);
      });
    }

    test('Private DNS off / automatic (null hostname) -> granted', () async {
      final r = await build(probe: loaded, dns: null).runIntegrityCheck();
      expect(r.isBlocked, isFalse);
    });
  });

  group('9 · recheck after the blocker is removed', () {
    test('a streak-confirmed block clears on the next clean check', () async {
      await Hive.box(HiveBoxes.settings).put(StorageKeys.adNetworkBlockStreak, 2);
      expect((await build(probe: allFailed(AdFailureKind.networkError))
          .runIntegrityCheck()).isBlocked, isTrue);
      final after = await build(probe: loaded).runIntegrityCheck();
      expect(after.isBlocked, isFalse);
      expect(streak(), 0);
    });
  });

  // ── Blocker screen + gate ───────────────────────────────────────────

  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  group('10-11 · blocker screen', () {
    testWidgets('English copy, Retry, and back cannot leave it', (tester) async {
      await tester.pumpWidget(app(AdBlockingDetectedScreen(
        onRetrySucceeded: () {},
        service: _FakeService(blocked: true),
      )));
      expect(find.text('Ads are required to use this app'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('Arabic copy', (tester) async {
      await tester.pumpWidget(app(
        AdBlockingDetectedScreen(onRetrySucceeded: () {}, service: _FakeService(blocked: true)),
        locale: const Locale('ar'),
      ));
      expect(find.text('الإعلانات مطلوبة لاستخدام هذا التطبيق'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('Retry while still blocked stays; once clear, leaves', (tester) async {
      final service = _FakeService(blocked: true);
      var cleared = 0;
      await tester.pumpWidget(app(AdBlockingDetectedScreen(
        onRetrySucceeded: () => cleared++,
        service: service,
      )));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(cleared, 0);
      service.blocked = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(cleared, 1);
    });

    testWidgets('returning to the app re-checks automatically', (tester) async {
      final service = _FakeService(blocked: false);
      var cleared = 0;
      await tester.pumpWidget(app(AdBlockingDetectedScreen(
        onRetrySucceeded: () => cleared++,
        service: service,
      )));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.calls, 1);
      expect(cleared, 1);
    });

    testWidgets('16 · after dispose a resume no longer re-checks', (tester) async {
      final service = _FakeService(blocked: true);
      await tester.pumpWidget(app(AdBlockingDetectedScreen(
        onRetrySucceeded: () {},
        service: service,
      )));
      await tester.pumpWidget(app(const SizedBox()));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.calls, 0);
    });
  });

  group('12-15 · gate: one blocker, no full-screen ads over it', () {
    late AdManager ads;
    setUp(() => ads = AdManager.forTesting()..debugSkipConsentForTests());

    testWidgets('a blocked post-Home check shows the blocker exactly once and '
        'suppresses App Open / Interstitial / Rewarded', (tester) async {
      final gate = AdIntegrityGate(service: () => _FakeService(blocked: true), ads: ads);
      late BuildContext ctx;
      await tester.pumpWidget(app(Builder(builder: (c) {
        ctx = c;
        return const Text('home');
      })));
      await gate.runPostHomeCheck(ctx);
      await tester.pumpAndSettle();
      expect(find.byType(AdBlockingDetectedScreen), findsOneWidget);
      expect(gate.isShowing, isTrue);
      expect(ads.isFullScreenSuppressed, isTrue);

      // A second check (or a second present) never stacks another blocker.
      await gate.runPostHomeCheck(ctx);
      expect(gate.present(Navigator.of(ctx), onCleared: () {}), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(AdBlockingDetectedScreen), findsOneWidget);
    });

    testWidgets('a clean post-Home check shows nothing and runs once', (tester) async {
      var runs = 0;
      final gate = AdIntegrityGate(
        service: () {
          runs++;
          return _FakeService(blocked: false);
        },
        ads: ads,
      );
      late BuildContext ctx;
      await tester.pumpWidget(app(Builder(builder: (c) {
        ctx = c;
        return const Text('home');
      })));
      await gate.runPostHomeCheck(ctx);
      await gate.runPostHomeCheck(ctx);
      await tester.pumpAndSettle();
      expect(find.byType(AdBlockingDetectedScreen), findsNothing);
      expect(runs, 1);
      expect(ads.isFullScreenSuppressed, isFalse);
    });

    testWidgets('removing the blocker route clears suppression', (tester) async {
      final gate = AdIntegrityGate(service: () => _FakeService(blocked: true), ads: ads);
      late BuildContext ctx;
      await tester.pumpWidget(app(Builder(builder: (c) {
        ctx = c;
        return const Text('home');
      })));
      gate.present(Navigator.of(ctx), onCleared: () {});
      await tester.pumpAndSettle();
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
      expect(gate.isShowing, isFalse);
      expect(ads.isFullScreenSuppressed, isFalse);
    });

    test('every full-screen show checks suppression before claiming the screen',
        () {
      final src = File('lib/core/ads/ad_manager.dart').readAsStringSync();
      for (final f in ['appOpen', 'interstitial', 'rewarded']) {
        final acquire = src.indexOf('_gate.tryAcquire(FullScreenAdFormat.$f)');
        final guard = src.lastIndexOf('if (_fullScreenSuppressed)', acquire);
        expect(guard, greaterThan(0), reason: '$f has a suppression guard');
        expect(src.substring(guard, acquire).contains('Future<'), isFalse,
            reason: '$f: the guard is inside the same show method');
      }
    });
  });
}

class _FakeSignals extends AdBlockDetectionService {
  _FakeSignals({this.vpn, this.dns});
  final bool? vpn;
  final String? dns;

  @override
  Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})>
      readVpnAndDnsSignals() async => (vpnActive: vpn, dnsHost: dns, dnsFiltering: null);
}

class _FakeService extends AdIntegrityService {
  _FakeService({required this.blocked}) : super(adBlockService: _FakeSignals());
  bool blocked;
  int calls = 0;

  @override
  Future<AdIntegrityResult> runIntegrityCheck() async {
    calls++;
    return AdIntegrityResult(
      status: blocked ? AdIntegrityStatus.blocked : AdIntegrityStatus.granted,
      reason: blocked ? AdBlockReason.dnsFilterDetected : AdBlockReason.none,
      diagnostics: const [],
    );
  }
}
