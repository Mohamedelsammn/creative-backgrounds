import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import 'ad_constants.dart';
import 'ad_show_policy.dart';

/// Centralized service for every AdMob full-screen ad - App Open,
/// Interstitial and the Rewarded unlock ad - plus the consent gate and the
/// "ads may be requested" signal banners wait on.
///
/// Rules this class guarantees:
///  * No ad request before UMP consent resolves and `canRequestAds()` allows
///    it ([ensureAdsReady], [whenAdsStarted]).
///  * One full-screen ad at a time ([FullScreenAdGate]).
///  * Splash never waits for an ad; App Open shows only on a safe moment.
///  * Every public method is failure-safe and never blocks navigation.
class AdManager {
  AdManager._() : _clock = DateTime.now;

  /// A fresh, non-singleton instance for tests, with an injectable clock.
  @visibleForTesting
  AdManager.forTesting({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final AdManager instance = AdManager._();

  final DateTime Function() _clock;

  // Memoized so every caller - main(), the ad-integrity probe, each banner
  // slot - awaits the SAME consent resolution instead of the second caller
  // returning early while consent is still pending.
  Future<void>? _initFuture;
  bool _adsStarted = false;
  final Completer<void> _adsStartedSignal = Completer<void>();
  static const Duration _consentTimeout = Duration(seconds: 10);

  final FullScreenAdGate _gate = FullScreenAdGate();
  final AppOpenPolicy _appOpenPolicy = AppOpenPolicy();
  final InterstitialApplyCounter _applyCounter = InterstitialApplyCounter();
  AppLifecycleListener? _lifecycle;

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;
  bool _isLoadingAppOpenAd = false;
  DateTime? _homeReadyAt;
  bool _coldStartHandled = false;

  // Diagnostic-only: the AdError.code from the most recent failed load, read
  // by the ad-integrity check to distinguish NO_FILL (normal, never
  // blocking-worthy) from a genuine network-level failure.
  int? _lastAppOpenErrorCode;

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  int? _lastInterstitialErrorCode;

  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  // A failed/no-fill load is very often transient, so a failure schedules
  // exactly one delayed retry instead of leaving the slot empty for the
  // rest of the session.
  static const Duration _preloadRetryDelay = Duration(seconds: 30);

  // ── Consent / initialization ────────────────────────────────────────

  /// Runs the UMP consent flow once per process, then initializes the Mobile
  /// Ads SDK and preloads App Open, Interstitial and Rewarded - but only if
  /// `canRequestAds()` allows it. Never throws, and never blocks startup for
  /// longer than [_consentTimeout]: if the user is still on the consent form
  /// at that point, ads start as soon as they finish it.
  Future<void> initialize() => _initFuture ??= _initialize();

  /// Resolves once the consent decision is known; true only when ad requests
  /// are permitted. Every ad request outside this class must await it.
  Future<bool> ensureAdsReady() async {
    await initialize();
    return _adsStarted;
  }

  /// Completes the moment ad requests become permitted - including late, e.g.
  /// after a consent form finished past [_consentTimeout]. Never completes if
  /// consent never permits ads.
  Future<void> get whenAdsStarted => _adsStartedSignal.future;

  /// Widget tests have no native UMP plugin, so the consent flow would never
  /// resolve and leave its timeout timer pending. Marks consent as resolved
  /// with ads NOT permitted.
  @visibleForTesting
  void debugSkipConsentForTests() {
    _initFuture = Future<void>.value();
    _adsStarted = false;
  }

  /// Marks ads as permitted without the SDK (tests only).
  @visibleForTesting
  void debugMarkAdsStartedForTests() => _markAdsStarted();

  void _markAdsStarted() {
    _adsStarted = true;
    if (!_adsStartedSignal.isCompleted) _adsStartedSignal.complete();
  }

  Future<void> _initialize() async {
    _lifecycle ??= AppLifecycleListener(
      onPause: () => onAppBackgrounded(),
      onResume: () => onAppForegrounded(),
    );
    final consentFlow = _requestConsentIfNeeded();
    var resolvedInTime = true;
    await consentFlow.timeout(
      _consentTimeout,
      onTimeout: () => resolvedInTime = false,
    );
    _log('Consent', 'resolved', {'inTime': resolvedInTime});
    final started = await _startAdsIfAllowed();
    if (!started && !resolvedInTime) {
      unawaited(consentFlow.then((_) => _startAdsIfAllowed()));
    }
  }

  Future<bool> _startAdsIfAllowed() async {
    if (_adsStarted) return true;
    bool allowed;
    try {
      allowed = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      allowed = false;
    }
    _log('Consent', 'canRequestAds', {'value': allowed});
    if (!allowed || _adsStarted) return _adsStarted;
    try {
      await MobileAds.instance.initialize();
      _log('SDK', 'initialized');
    } catch (e) {
      // Never crash app startup because ads failed to initialize.
      _log('SDK', 'initializeFailed', {'error': e.runtimeType});
    }
    _markAdsStarted();
    unawaited(preloadAppOpenAd());
    unawaited(_preloadInterstitial());
    unawaited(_preloadRewarded());
    return true;
  }

  /// Runs the UMP consent-info-update + form flow. Completes when consent is
  /// resolved (obtained, not required, form dismissed, or the flow failed).
  Future<void> _requestConsentIfNeeded() {
    final completer = Completer<void>();
    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
              )
            : null,
      );
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {
              if (!completer.isCompleted) completer.complete();
            });
          } catch (_) {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (_) {
          // Consent info update failed (e.g. offline) - fall through rather
          // than blocking startup on a UMP-specific network error.
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  /// Shows Google's privacy-options form (the UMP "manage consent" re-entry
  /// point), for a Settings screen entry. Required by UMP policy whenever
  /// [ConsentInformation.getPrivacyOptionsRequirementStatus] reports
  /// `required` - see `PrivacyOptionsRequirementStatus`.
  Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {
        if (!completer.isCompleted) completer.complete();
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    await completer.future;
    await _startAdsIfAllowed();
  }

  /// Whether any full-screen ad currently owns the screen.
  bool get isShowingFullScreenAd => _gate.isShowing;

  bool _fullScreenSuppressed = false;

  /// While the ads-blocked screen is up, no App Open, Interstitial or
  /// Rewarded may show over it (e.g. a resume after the user went to turn
  /// Private DNS off). Preloading is unaffected.
  void setFullScreenAdsSuppressed(bool suppressed) {
    if (_fullScreenSuppressed == suppressed) return;
    _fullScreenSuppressed = suppressed;
    _log('Gate', 'fullScreenSuppressed', {'value': suppressed});
  }

  bool get isFullScreenSuppressed => _fullScreenSuppressed;

  // ── App lifecycle / App Open ────────────────────────────────────────

  /// Called when the app goes to the background. A pause caused by our own
  /// full-screen ad is not a real background, so it is ignored.
  @visibleForTesting
  void onAppBackgrounded() {
    if (_gate.isShowing) return;
    _appOpenPolicy.onBackgrounded(_clock());
  }

  /// Called when the app returns to the foreground. Shows an App Open only
  /// after at least 30 s away, never right after an Apply's system picker,
  /// and never twice for duplicate callbacks.
  @visibleForTesting
  void onAppForegrounded() {
    if (!_appOpenPolicy.shouldShowOnResume(_clock())) return;
    _log('AppOpen', 'resumeEligible', {'ready': isAppOpenReady});
    unawaited(showAppOpenIfAvailable());
  }

  /// A wallpaper Apply is starting: the system wallpaper picker may open,
  /// and coming back from it must not trigger an App Open.
  void beginWallpaperApply() {
    _appOpenPolicy.suppressNextResume();
    _coldStartHandled = true;
  }

  /// Home is on screen (Splash finished). Splash never waits for this: an
  /// App Open that is already loaded shows now; one still loading may show
  /// when it arrives, within the short cold-start window.
  void onHomeReady() {
    if (_homeReadyAt != null) return;
    _homeReadyAt = _clock();
    _log('AppOpen', 'homeReady', {'ready': isAppOpenReady});
    if (isAppOpenReady) {
      _coldStartHandled = true;
      unawaited(showAppOpenIfAvailable());
    }
  }

  void _maybeShowColdStartAppOpen() {
    final homeReadyAt = _homeReadyAt;
    if (_coldStartHandled || homeReadyAt == null) return;
    _coldStartHandled = true;
    if (!_appOpenPolicy.withinColdStartWindow(homeReadyAt, _clock())) {
      _log('AppOpen', 'coldStartWindowMissed');
      return;
    }
    unawaited(showAppOpenIfAvailable());
  }

  Future<void> preloadAppOpenAd() async {
    if (!_adsStarted || _appOpenAd != null || _isLoadingAppOpenAd) return;
    _isLoadingAppOpenAd = true;
    _log('AppOpen', 'request');
    try {
      await AppOpenAd.load(
        adUnitId: AdConstants.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenLoadedAt = _clock();
            _isLoadingAppOpenAd = false;
            _lastAppOpenErrorCode = null;
            _logLoaded('AppOpen', ad.responseInfo);
            _maybeShowColdStartAppOpen();
          },
          onAdFailedToLoad: (error) {
            _isLoadingAppOpenAd = false;
            _lastAppOpenErrorCode = error.code;
            _logError('AppOpen', 'failedToLoad', error);
            Future.delayed(_preloadRetryDelay, preloadAppOpenAd);
          },
        ),
      );
    } catch (_) {
      _isLoadingAppOpenAd = false;
      Future.delayed(_preloadRetryDelay, preloadAppOpenAd);
    }
  }

  /// Whether a loaded, unexpired App Open is ready.
  bool get isAppOpenReady {
    final loadedAt = _appOpenLoadedAt;
    if (_appOpenAd == null || loadedAt == null) return false;
    return !_appOpenPolicy.isExpired(loadedAt, _clock());
  }

  /// Whether the App Open preload is currently in flight.
  bool get isAppOpenLoading => _isLoadingAppOpenAd;

  /// The `AdError.code` from the most recent failed App Open load, if any.
  /// Diagnostic-only - never consulted by ad-serving logic.
  int? get lastAppOpenErrorCode => _lastAppOpenErrorCode;

  /// Shows the App Open ad if one is loaded and unexpired and no other
  /// full-screen ad is showing. Returns whether it was shown. Never waits.
  Future<bool> showAppOpenIfAvailable() async {
    final ad = _appOpenAd;
    final loadedAt = _appOpenLoadedAt;
    if (ad == null || loadedAt == null) {
      _log('AppOpen', 'notReady');
      unawaited(preloadAppOpenAd());
      return false;
    }
    if (_appOpenPolicy.isExpired(loadedAt, _clock())) {
      _log('AppOpen', 'expired');
      _appOpenAd = null;
      _appOpenLoadedAt = null;
      unawaited(ad.dispose());
      unawaited(preloadAppOpenAd());
      return false;
    }
    if (_fullScreenSuppressed) {
      _log('AppOpen', 'suppressed');
      return false;
    }
    if (!_gate.tryAcquire(FullScreenAdFormat.appOpen)) {
      _log('AppOpen', 'blocked', {'showing': _gate.showing?.name});
      return false;
    }
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _log('AppOpen', 'show'),
      onAdDismissedFullScreenContent: (ad) {
        _log('AppOpen', 'dismissed');
        _gate.release(FullScreenAdFormat.appOpen);
        ad.dispose();
        unawaited(preloadAppOpenAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logError('AppOpen', 'failedToShow', error);
        _gate.release(FullScreenAdFormat.appOpen);
        ad.dispose();
        unawaited(preloadAppOpenAd());
      },
    );
    try {
      await ad.show();
      return true;
    } catch (_) {
      _gate.release(FullScreenAdFormat.appOpen);
      unawaited(preloadAppOpenAd());
      return false;
    }
  }

  // ── Interstitial — every third successful Apply ─────────────────────

  /// Whether the interstitial slot currently has a ready ad.
  bool get isInterstitialReady => _interstitialAd != null;

  /// Whether the interstitial preload is currently in flight.
  bool get isInterstitialLoading => _isLoadingInterstitial;

  /// The `AdError.code` from the most recent failed interstitial load, if
  /// any. Diagnostic-only, same purpose as [lastAppOpenErrorCode].
  int? get lastInterstitialErrorCode => _lastInterstitialErrorCode;

  /// Number of successful applies recorded this session.
  @visibleForTesting
  int get successfulApplies => _applyCounter.successfulApplies;

  /// Call ONLY after a wallpaper Apply has completed successfully (never on
  /// failure or cancel). Applies #3, #6, #9 ... attempt an interstitial.
  /// Returns immediately - the ad, if any, is shown without being awaited,
  /// so it can never delay or block the Apply. Returns whether this apply
  /// was an eligible (every-third) one.
  bool onWallpaperApplied() {
    final eligible = _applyCounter.recordSuccessfulApply();
    _log('Interstitial', 'applyCounted', {
      'count': _applyCounter.successfulApplies,
      'eligible': eligible,
      'ready': isInterstitialReady,
    });
    if (eligible) unawaited(showInterstitial());
    return eligible;
  }

  Future<void> _preloadInterstitial() async {
    if (!_adsStarted || _interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;
    _log('Interstitial', 'request');
    try {
      await InterstitialAd.load(
        adUnitId: AdConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isLoadingInterstitial = false;
            _lastInterstitialErrorCode = null;
            _logLoaded('Interstitial', ad.responseInfo);
          },
          onAdFailedToLoad: (error) {
            _isLoadingInterstitial = false;
            _lastInterstitialErrorCode = error.code;
            _logError('Interstitial', 'failedToLoad', error);
            Future.delayed(_preloadRetryDelay, _preloadInterstitial);
          },
        ),
      );
    } catch (_) {
      _isLoadingInterstitial = false;
      Future.delayed(_preloadRetryDelay, _preloadInterstitial);
    }
  }

  /// Shows the preloaded interstitial, if any and if no other full-screen ad
  /// is showing, then loads its replacement. Never throws, never waits for a
  /// load; resolves when the ad is dismissed or immediately if none showed.
  Future<void> showInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) {
      _log('Interstitial', 'notReady');
      unawaited(_preloadInterstitial());
      return;
    }
    if (_fullScreenSuppressed) {
      _log('Interstitial', 'suppressed');
      return;
    }
    if (!_gate.tryAcquire(FullScreenAdFormat.interstitial)) {
      _log('Interstitial', 'blocked', {'showing': _gate.showing?.name});
      return;
    }
    _interstitialAd = null;
    unawaited(_preloadInterstitial());

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _log('Interstitial', 'show'),
      onAdDismissedFullScreenContent: (ad) {
        _log('Interstitial', 'dismissed');
        _gate.release(FullScreenAdFormat.interstitial);
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logError('Interstitial', 'failedToShow', error);
        _gate.release(FullScreenAdFormat.interstitial);
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
    } catch (_) {
      _gate.release(FullScreenAdFormat.interstitial);
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  // ── Rewarded Ad — preloaded ahead; unlocks a PRO wallpaper's Apply ────

  Future<void> _preloadRewarded() async {
    if (!_adsStarted || _rewardedAd != null || _isLoadingRewarded) return;
    _isLoadingRewarded = true;
    _log('Rewarded', 'request');
    try {
      await RewardedAd.load(
        adUnitId: AdConstants.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoadingRewarded = false;
            _logLoaded('Rewarded', ad.responseInfo);
          },
          onAdFailedToLoad: (error) {
            _isLoadingRewarded = false;
            _logError('Rewarded', 'failedToLoad', error);
            Future.delayed(_preloadRetryDelay, _preloadRewarded);
          },
        ),
      );
    } catch (_) {
      _isLoadingRewarded = false;
      Future.delayed(_preloadRetryDelay, _preloadRewarded);
    }
  }

  /// Whether a rewarded ad is currently ready to show - lets the Apply flow
  /// decide up front whether to offer "Watch ad to unlock" at all, rather
  /// than showing that choice and then failing.
  bool get isRewardedReady => _rewardedAd != null;

  /// Shows the preloaded rewarded ad, if any, and immediately starts loading
  /// its replacement so the network wait happens in the background while
  /// the current ad plays.
  ///
  /// Returns true only if the user watched to completion and the reward
  /// callback fired (AdMob's `onUserEarnedReward`). Returns false if no ad
  /// is preloaded, another full-screen ad is showing, it fails to show, or
  /// the user skips/closes early - the caller (the PRO-unlock gate) must not
  /// grant access in that case.
  Future<bool> showRewardedAdForUnlock() async {
    final ad = _rewardedAd;
    if (ad == null) {
      _log('Rewarded', 'notReady');
      return false;
    }
    if (_fullScreenSuppressed) {
      _log('Rewarded', 'suppressed');
      return false;
    }
    if (!_gate.tryAcquire(FullScreenAdFormat.rewarded)) {
      _log('Rewarded', 'blocked', {'showing': _gate.showing?.name});
      return false;
    }
    _rewardedAd = null;
    unawaited(_preloadRewarded());

    final completer = Completer<bool>();
    bool earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _log('Rewarded', 'show'),
      onAdDismissedFullScreenContent: (ad) {
        _log('Rewarded', 'dismissed', {'earned': earned});
        _gate.release(FullScreenAdFormat.rewarded);
        ad.dispose();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logError('Rewarded', 'failedToShow', error);
        _gate.release(FullScreenAdFormat.rewarded);
        ad.dispose();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earned = true;
        },
      );
    } catch (_) {
      _gate.release(FullScreenAdFormat.rewarded);
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  // ── Diagnostics ─────────────────────────────────────────────────────

  static void _log(String format, String event, [Map<String, Object?> data = const {}]) {
    if (!AppConfig.adsDiagnostics) return;
    final details = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    debugPrint('[ADS][$format] $event${details.isEmpty ? '' : ' $details'}');
  }

  static void _logLoaded(String format, ResponseInfo? info) =>
      _log(format, 'loaded', {'responseId': info?.responseId, 'adapter': info?.mediationAdapterClassName});

  static void _logError(String format, String event, AdError error) {
    final info = error is LoadAdError ? error.responseInfo : null;
    _log(format, event, {
      'code': error.code,
      'domain': error.domain,
      'message': error.message,
      'responseId': info?.responseId,
      'adapter': info?.mediationAdapterClassName,
    });
  }

  /// Public diagnostics entry point for banner placements.
  static void logBanner(String format, String event, [Map<String, Object?> data = const {}]) =>
      _log(format, event, data);

  static void logBannerError(String format, String event, AdError error) =>
      _logError(format, event, error);
}
