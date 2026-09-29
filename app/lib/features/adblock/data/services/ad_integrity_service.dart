import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/ads/ad_constants.dart';
import '../../../../core/ads/ad_manager.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/ad_integrity_result.dart';
import 'ad_block_detection_service.dart';

/// Coarse classification of why a single ad request failed, used only to
/// decide whether the failure is admissible evidence toward the
/// cross-session ad-blocking streak below. Built from the real Google
/// Mobile Ads `AdError.code`:
///   0 = internal error, 1 = invalid request, 2 = network error, 3 = no fill.
/// See https://developers.google.com/admob/android/reference/com/google/android/gms/ads/AdRequest
enum _AdFailureKind {
  /// No error observed (ad loaded, or probe never ran).
  none,

  /// AdError.code == 3. Google's ad servers were reached and responded -
  /// this is direct proof the request was NOT blocked, it simply had no
  /// inventory to serve. Never admissible as ad-blocking evidence.
  noFill,

  /// AdError.code == 2. The request could not reach the ad server at all.
  /// This is the only failure shape consistent with DNS/firewall-level ad
  /// blocking, but is still not sufficient alone - see
  /// [AdIntegrityService._networkBlockStreakThreshold].
  networkError,

  /// Any other AdError code, an exception, or a probe that never resolved
  /// before the outer timeout. Ambiguous - never admissible as evidence.
  other,
}

_AdFailureKind _classifyErrorCode(int? code) {
  switch (code) {
    case null:
      return _AdFailureKind.none;
    case 3:
      return _AdFailureKind.noFill;
    case 2:
      return _AdFailureKind.networkError;
    default:
      return _AdFailureKind.other;
  }
}

String _kindLabel(_AdFailureKind kind) {
  switch (kind) {
    case _AdFailureKind.none:
      return 'none';
    case _AdFailureKind.noFill:
      return 'NO_FILL — normal, not blocking-eligible';
    case _AdFailureKind.networkError:
      return 'NETWORK_ERROR';
    case _AdFailureKind.other:
      return 'other/ambiguous — not blocking-eligible';
  }
}

/// Startup gate that decides whether the app is allowed to proceed past
/// Splash. The app is ad-funded, so a device with strong, direct evidence of
/// actively blocking ads (an active VPN, a known ad-blocking private-DNS
/// provider, or several consecutive sessions of every ad request failing
/// with NETWORK_ERROR while general internet connectivity is otherwise
/// healthy) must not reach Explore.
///
/// A single failed or no-fill ad request is NOT such evidence - NO_FILL,
/// invalid-request, internal, and other ambiguous AdMob errors are normal,
/// everyday outcomes (new AdMob account, low-inventory region, temporary
/// shortage, emulator, first-ever app launch) and never gate access on their
/// own. See [_AdFailureKind] for the full classification.
///
/// VPN/private-DNS signals are read via [AdBlockDetectionService] (this
/// app's existing, already-wired native channel), not re-implemented here -
/// this service only adds the ad-load probe and the cross-session streak on
/// top of those signals.
///
/// This service owns no UI and no navigation - it only runs checks and
/// returns an [AdIntegrityResult]. The caller (`SplashBloc`) decides what to
/// do with the result. Every check is independently failure-safe: no
/// combination of missing internet, a Google Mobile Ads outage, no ad
/// inventory, or a missing native platform implementation will ever throw
/// out of [runIntegrityCheck].
class AdIntegrityService {
  AdIntegrityService({
    AdBlockDetectionService? adBlockService,
    HiveStorage? storage,
  }) : _adBlockService = adBlockService ?? AdBlockDetectionService(),
       _storage = storage ?? HiveStorage();

  final AdBlockDetectionService _adBlockService;
  final HiveStorage _storage;

  static const Duration _checkTimeout = Duration(seconds: 10);
  static const Duration _connectivityCheckTimeout = Duration(seconds: 4);

  /// Consecutive sessions of "every ad failed with NETWORK_ERROR while
  /// connectivity is healthy" required before this is treated as real
  /// ad-blocking rather than a one-off network blip.
  static const int _networkBlockStreakThreshold = 3;

  static const _AdProbeOutcome _timedOutProbeOutcome = _AdProbeOutcome(
    sdkInitialized: false,
    bannerLoaded: false,
    interstitialLoaded: false,
    appOpenLoaded: false,
    bannerFailureKind: _AdFailureKind.other,
    interstitialFailureKind: _AdFailureKind.other,
    appOpenFailureKind: _AdFailureKind.other,
  );

  static const _AdProbeOutcome _consentNotGrantedProbeOutcome = _AdProbeOutcome(
    sdkInitialized: true,
    bannerLoaded: false,
    interstitialLoaded: false,
    appOpenLoaded: false,
    bannerFailureKind: _AdFailureKind.other,
    interstitialFailureKind: _AdFailureKind.other,
    appOpenFailureKind: _AdFailureKind.other,
    diagnostics: ['[AD_CHECK] Ads not requested - consent does not permit'],
  );

  /// Case-insensitive substrings matched against the device's configured
  /// Private DNS hostname to identify known ad-blocking DNS providers.
  /// Deliberately the same list `NetworkInterferenceProbe.kt` already
  /// checks natively, kept here too since `AdBlockDetectionService.detect()`
  /// applies its own matching only inside its combined report - this
  /// service needs the raw hostname to classify independently of that
  /// report's reachability-probe-driven verdict.
  static const List<String> _knownAdBlockDnsPatterns = [
    'adguard',
    'nextdns',
    'controld',
    'mullvad',
    'blahdns',
    'rethinkdns',
    'pi-hole',
    'cleanbrowsing',
    'quad9',
  ];

  Future<AdIntegrityResult> runIntegrityCheck() async {
    final diagnostics = <String>[];

    // Neither depends on the other's result - only the synthesis logic below
    // needs both together - so start them together instead of awaiting one
    // at a time. The ad probe is the dominant cost (up to _checkTimeout), so
    // this overlaps the near-instant native VPN/DNS read with it instead of
    // adding their time on top.
    final signalsFuture = _safeSignals(_adBlockService.readVpnAndDnsSignals);
    final probeFuture = _probeAds().timeout(
      _checkTimeout,
      onTimeout: () => _timedOutProbeOutcome,
    );

    final signals = await signalsFuture;
    final vpnDetected = signals.vpnActive == true;
    if (vpnDetected) diagnostics.add('[AD_CHECK] VPN detected');

    final dnsHostname = signals.dnsHost;
    final dnsFilterDetected =
        dnsHostname != null && _matchesKnownAdBlockDns(dnsHostname);
    if (dnsFilterDetected) {
      diagnostics.add('[AD_CHECK] DNS filter detected ($dnsHostname)');
    }

    var probe = await probeFuture;
    diagnostics.addAll(probe.diagnostics);

    var allAdsFailed =
        !probe.bannerLoaded &&
        !probe.interstitialLoaded &&
        !probe.appOpenLoaded;

    // A device's very first ad request after install is often slower than
    // steady-state (cold SDK init, no cached creative), which can exceed the
    // timeout with no real ad-blocking present. Give a full-failure exactly
    // one retry, but only on the very first integrity check this install
    // ever runs - VPN/DNS signals are never retried, they are immediate
    // OS-level facts, not subject to ad-network warm-up.
    if (!dnsFilterDetected && (allAdsFailed || !probe.sdkInitialized)) {
      final isFirstRun = await _isFirstIntegrityRun();
      if (isFirstRun) {
        diagnostics.add('[AD_CHECK] First run — retrying ad probe once');
        probe = await _probeAds().timeout(
          _checkTimeout,
          onTimeout: () => _timedOutProbeOutcome,
        );
        diagnostics.addAll(probe.diagnostics);
        allAdsFailed =
            !probe.bannerLoaded &&
            !probe.interstitialLoaded &&
            !probe.appOpenLoaded;
      }
    }

    // ── Cross-session network-blocking streak ───────────────────────────
    // Runs whenever a DNS filter has not already been named outright - a
    // benign VPN being present must not stop streak accounting, or a VPN
    // user whose ad traffic really is being filtered would never accumulate
    // the corroborating evidence below.
    var networkBlockingConfirmed = false;
    if (!dnsFilterDetected) {
      final allNetworkError =
          allAdsFailed &&
          probe.bannerFailureKind == _AdFailureKind.networkError &&
          probe.interstitialFailureKind == _AdFailureKind.networkError &&
          probe.appOpenFailureKind == _AdFailureKind.networkError;

      if (allNetworkError) {
        final connectivityHealthy = await _hasHealthyConnectivity();
        if (connectivityHealthy) {
          final streak = _readStreak() + 1;
          await _writeStreak(streak);
          diagnostics.add(
            '[AD_CHECK] All ad requests failed with NETWORK_ERROR while '
            'connectivity is healthy — streak $streak/$_networkBlockStreakThreshold',
          );
          networkBlockingConfirmed = streak >= _networkBlockStreakThreshold;
        } else {
          diagnostics.add(
            '[AD_CHECK] Ad requests failed with NETWORK_ERROR but general '
            'connectivity is also unhealthy — not attributable to ad '
            'blocking, streak reset',
          );
          await _writeStreak(0);
        }
      } else {
        if (allAdsFailed) {
          diagnostics.add(
            '[AD_CHECK] All ads failed but not purely NETWORK_ERROR '
            '(NO_FILL / other) — normal AdMob behavior, streak reset',
          );
        }
        await _writeStreak(0);
      }
    }

    // A VPN alone is NOT evidence of ad blocking, and must never gate access
    // on its own: corporate VPNs, privacy VPNs, Cloudflare WARP and
    // tethering/hotspot helpers all register as TRANSPORT_VPN while ads keep
    // serving perfectly. Blocking on the bare signal (as the reference
    // implementation this was ported from did) locks out a large set of
    // entirely legitimate users. It only counts once corroborated by ads
    // genuinely failing to REACH the network in this same pass - i.e. the
    // tunnel is demonstrably filtering ad traffic rather than merely
    // existing. A known ad-blocking private-DNS hostname stays sufficient on
    // its own: that string names a filtering service explicitly, so there is
    // no ambiguity to corroborate.
    final vpnFilteringCorroborated =
        vpnDetected &&
        allAdsFailed &&
        probe.bannerFailureKind == _AdFailureKind.networkError &&
        probe.interstitialFailureKind == _AdFailureKind.networkError &&
        probe.appOpenFailureKind == _AdFailureKind.networkError;
    if (vpnDetected && !vpnFilteringCorroborated) {
      diagnostics.add(
        '[AD_CHECK] VPN present but ads are not network-blocked — treated as '
        'a benign VPN, not ad blocking',
      );
    }

    AdBlockReason reason = AdBlockReason.none;
    if (vpnFilteringCorroborated) {
      reason = AdBlockReason.vpnDetected;
    } else if (dnsFilterDetected) {
      reason = AdBlockReason.dnsFilterDetected;
    } else if (networkBlockingConfirmed) {
      reason = AdBlockReason.adsFailedToLoad;
    }

    final blocked = reason != AdBlockReason.none;
    diagnostics.add(
      blocked
          ? '[AD_CHECK] Access blocked (reason: $reason)'
          : '[AD_CHECK] Access granted',
    );

    if (kDebugMode) {
      for (final line in diagnostics) {
        debugPrint(line);
      }
    }

    return AdIntegrityResult(
      status: blocked ? AdIntegrityStatus.blocked : AdIntegrityStatus.granted,
      reason: reason,
      diagnostics: diagnostics,
    );
  }

  /// Startup-safe integrity pass. It reads only immediate, local OS-level
  /// signals and deliberately does not wait for ad inventory or any network
  /// probe - a slow AdMob request must never hold Splash hostage.
  ///
  /// Only a named ad-blocking private-DNS hostname can gate startup here. A
  /// bare VPN cannot: with no ad probe in this pass there is nothing to
  /// corroborate it against, and blocking on the raw signal would lock out
  /// every corporate/privacy-VPN user whose ads work fine. Those users
  /// instead reach Home normally, and the full [runIntegrityCheck] - which
  /// does have probe evidence, and requires a multi-session streak - remains
  /// the only path that can ever attribute blocking to a VPN.
  Future<AdIntegrityResult> runStartupIntegrityCheck() async {
    final signals = await _safeSignals(_adBlockService.readVpnAndDnsSignals);
    final dnsHostname = signals.dnsHost;
    final dnsFilterDetected =
        dnsHostname != null && _matchesKnownAdBlockDns(dnsHostname);
    final reason = dnsFilterDetected
        ? AdBlockReason.dnsFilterDetected
        : AdBlockReason.none;
    return AdIntegrityResult(
      status: reason == AdBlockReason.none
          ? AdIntegrityStatus.granted
          : AdIntegrityStatus.blocked,
      reason: reason,
      diagnostics: const ['[AD_CHECK] Startup-safe local signal pass'],
    );
  }

  bool _matchesKnownAdBlockDns(String hostname) {
    final lower = hostname.toLowerCase();
    return _knownAdBlockDnsPatterns.any(lower.contains);
  }

  Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})> _safeSignals(
    Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})> Function()
    fn,
  ) async {
    try {
      return await fn();
    } catch (_) {
      return (vpnActive: null, dnsHost: null, dnsFiltering: null);
    }
  }

  Future<bool> _isFirstIntegrityRun() async {
    final seen = _storage.read<bool>(
      HiveBoxes.settings,
      StorageKeys.adIntegrityFirstRun,
    );
    if (seen == true) return false;
    await _storage.write(
      HiveBoxes.settings,
      StorageKeys.adIntegrityFirstRun,
      true,
    );
    return true;
  }

  int _readStreak() =>
      _storage.read<int>(
        HiveBoxes.settings,
        StorageKeys.adNetworkBlockStreak,
      ) ??
      0;

  Future<void> _writeStreak(int value) => _storage.write(
    HiveBoxes.settings,
    StorageKeys.adNetworkBlockStreak,
    value,
  );

  /// A DNS lookup against a well-known non-ad domain, used purely to prove
  /// the device has *general* internet connectivity - independent of
  /// whether Google's ad domains specifically are reachable. Failure-safe:
  /// any error or timeout resolves to "unhealthy" rather than throwing.
  Future<bool> _hasHealthyConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(_connectivityCheckTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<_AdProbeOutcome> _probeAds() async {
    bool sdkInitialized = false;
    try {
      // Awaits the same memoized consent + SDK init main() started, so the
      // probe banner below can never be requested before UMP consent
      // resolves.
      if (!await AdManager.instance.ensureAdsReady()) {
        // Consent does not permit ad requests: nothing to probe. `other` is
        // never counted as network-blocking evidence, so this can't produce
        // an ad-blocker verdict.
        return _consentNotGrantedProbeOutcome;
      }
      sdkInitialized = true;
    } catch (_) {
      sdkInitialized = false;
    }

    final results = await Future.wait<({bool loaded, _AdFailureKind kind})>([
      _probeBanner(),
      _waitForAdManagerSignal(
        isReady: () => AdManager.instance.isInterstitialReady,
        isLoading: () => AdManager.instance.isInterstitialLoading,
      ).then(
        (loaded) => (
          loaded: loaded,
          kind: loaded
              ? _AdFailureKind.none
              : _classifyErrorCode(
                  AdManager.instance.lastInterstitialErrorCode,
                ),
        ),
      ),
      _waitForAdManagerSignal(
        isReady: () => AdManager.instance.isAppOpenReady,
        isLoading: () => AdManager.instance.isAppOpenLoading,
      ).then(
        (loaded) => (
          loaded: loaded,
          kind: loaded
              ? _AdFailureKind.none
              : _classifyErrorCode(AdManager.instance.lastAppOpenErrorCode),
        ),
      ),
    ]);

    final banner = results[0];
    final interstitial = results[1];
    final appOpen = results[2];

    return _AdProbeOutcome(
      sdkInitialized: sdkInitialized,
      bannerLoaded: banner.loaded,
      interstitialLoaded: interstitial.loaded,
      appOpenLoaded: appOpen.loaded,
      bannerFailureKind: banner.kind,
      interstitialFailureKind: interstitial.kind,
      appOpenFailureKind: appOpen.kind,
      diagnostics: [
        banner.loaded
            ? '[AD_CHECK] Banner loaded'
            : '[AD_CHECK] Banner failed (${_kindLabel(banner.kind)})',
        interstitial.loaded
            ? '[AD_CHECK] Interstitial loaded'
            : '[AD_CHECK] Interstitial failed (${_kindLabel(interstitial.kind)})',
        appOpen.loaded
            ? '[AD_CHECK] App Open loaded'
            : '[AD_CHECK] App Open failed (${_kindLabel(appOpen.kind)})',
      ],
    );
  }

  Future<({bool loaded, _AdFailureKind kind})> _probeBanner() {
    final completer = Completer<({bool loaded, _AdFailureKind kind})>();
    try {
      final ad = BannerAd(
        adUnitId: AdConstants.bottomBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            ad.dispose();
            if (!completer.isCompleted) {
              completer.complete((loaded: true, kind: _AdFailureKind.none));
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!completer.isCompleted) {
              completer.complete((
                loaded: false,
                kind: _classifyErrorCode(error.code),
              ));
            }
          },
        ),
      );
      ad.load();
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete((loaded: false, kind: _AdFailureKind.other));
      }
    }
    return completer.future;
  }

  /// Polls an AdManager preload signal instead of loading a separate probe
  /// ad - removes the startup contention of two independent ad requests
  /// competing for the same ad unit at the same moment. Bounded by the
  /// outer [_checkTimeout] applied in [runIntegrityCheck].
  Future<bool> _waitForAdManagerSignal({
    required bool Function() isReady,
    required bool Function() isLoading,
  }) async {
    while (true) {
      if (isReady()) return true;
      if (!isLoading()) return false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}

class _AdProbeOutcome {
  const _AdProbeOutcome({
    required this.sdkInitialized,
    required this.bannerLoaded,
    required this.interstitialLoaded,
    required this.appOpenLoaded,
    this.bannerFailureKind = _AdFailureKind.none,
    this.interstitialFailureKind = _AdFailureKind.none,
    this.appOpenFailureKind = _AdFailureKind.none,
    this.diagnostics = const [],
  });

  final bool sdkInitialized;
  final bool bannerLoaded;
  final bool interstitialLoaded;
  final bool appOpenLoaded;
  final _AdFailureKind bannerFailureKind;
  final _AdFailureKind interstitialFailureKind;
  final _AdFailureKind appOpenFailureKind;
  final List<String> diagnostics;
}
