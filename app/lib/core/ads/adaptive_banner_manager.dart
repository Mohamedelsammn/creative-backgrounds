import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_constants.dart';
import 'ad_show_policy.dart';
import 'ad_manager.dart';

/// Owns exactly one anchored adaptive [BannerAd] for its lifetime, reused
/// wherever a single persistent banner placement is needed (Home's
/// between-sections banners, View All's bottom anchor).
///
/// [loaded] is reactive: the consuming widget collapses to zero height
/// whenever it's false (still loading, no-fill, or failed) and shows the ad
/// normally the moment it - or a retry - succeeds. This is what guarantees a
/// banner placement is never an empty/placeholder card - see
/// [AdaptiveBannerAd].
///
/// Uses a standard anchored ADAPTIVE banner (never a fixed size) - [adSize]
/// is only known once [load] resolves, sized for the width supplied at that
/// time, and its `.height` (device/orientation dependent, typically
/// 50-90dp) is the ONLY source of truth the consuming widget should use for
/// how tall the banner area is.
///
/// Call [dispose] exactly once, when the owning widget is torn down.
class AdaptiveBannerManager {
  AdaptiveBannerManager(this.adUnitId) {
    // A cached height from any earlier manager (this session, this width)
    // is available synchronously - reserve it immediately instead of the
    // wrong 50dp `AdSize.banner` placeholder, so this slot's height never
    // has to change again once `load()`'s async resolution completes. See
    // `_cachedHeightByWidth`'s doc for why this is safe.
    final cached = _cachedHeightByWidth.values.firstOrNull;
    if (cached != null) size.value = cached;
  }

  final String adUnitId;

  // Same retry policy already used for the other ad types: one delayed
  // retry after a failed/no-fill load - long enough to not look like a
  // retry storm, short enough to still recover within the same session.
  static const Duration _retryDelay = Duration(seconds: 30);

  /// Adaptive banner height only depends on device width and orientation,
  /// both effectively constant for a running session (a rotation is rare
  /// for a portrait-locked wallpaper app, and even then every manager
  /// re-resolves against the new width the next time `load` is called with
  /// it). Caching by width lets every banner slot AFTER THE FIRST reserve
  /// its real height from the very first frame - never the wrong 50dp
  /// `AdSize.banner` placeholder that used to visibly change size (and shift
  /// every sliver below it) once the async AdMob call resolved. This is
  /// exactly what caused the reported "feed jumps when reaching an ad":
  /// each new banner slot laid out 50dp tall, then grew to the real
  /// (device-dependent, typically 50-90dp) adaptive height a frame or two
  /// later, pushing everything below it down mid-scroll.
  static final Map<int, AdSize> _cachedHeightByWidth = {};

  /// Shared by every banner, so slots on the same unit never request in a
  /// burst - see [AdUnitRequestPacer].
  static final AdUnitRequestPacer _pacer = AdUnitRequestPacer();

  final ValueNotifier<bool> loaded = ValueNotifier(false);
  final ValueNotifier<AdSize?> size = ValueNotifier(null);

  BannerAd? _ad;
  bool _isLoading = false;
  bool _retried = false;
  bool _disposed = false;
  bool _waitingForAds = false;
  AdUnitTurn? _unitTurn;

  /// Diagnostics label: the Home in-feed slot vs a bottom banner.
  String get _format =>
      adUnitId == AdConstants.inFeedBannerAdUnitId ? 'InFeedBanner' : 'Banner';

  BannerAd? get ad => _ad;

  /// The adaptive size the current/last load attempt was sized for. Set as
  /// soon as [load] resolves a size from AdMob, independent of whether the
  /// ad itself has finished loading yet - [loaded] still gates visibility.
  AdSize? get adSize => size.value;

  /// Starts loading the banner, sized as a standard anchored adaptive banner
  /// for [width] logical pixels (current orientation) - a no-op if already
  /// loaded or in flight. Idempotent - safe to call repeatedly.
  Future<void> load(int width) async {
    if (_disposed || _ad != null || _isLoading) return;
    _isLoading = true;
    // No ad request before UMP consent permits one (EEA/UK).
    final ready = await AdManager.instance.ensureAdsReady();
    if (_disposed) return;
    if (!ready) {
      _isLoading = false;
      AdManager.logBanner(_format, 'notEligible', {'canRequestAds': false});
      // Consent may still permit ads later (e.g. a consent form finished
      // after the startup timeout). Retry exactly once when it does.
      if (!_waitingForAds) {
        _waitingForAds = true;
        unawaited(AdManager.instance.whenAdsStarted.then((_) {
          if (!_disposed && _ad == null) load(width);
        }));
      }
      return;
    }
    final cached = _cachedHeightByWidth[width];
    if (cached != null) {
      // Already known for this exact width - skip the async native round
      // trip entirely and reuse it synchronously-equivalent (still a
      // microtask away, but with no risk of resolving to a different
      // height than what this slot already reserved in the constructor).
      size.value = cached;
    }
    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (_disposed) return;
    if (adaptiveSize == null) {
      // Could not compute an adaptive size for this width - treat exactly
      // like a failed load so the existing retry policy still applies.
      _isLoading = false;
      _scheduleRetry(width);
      return;
    }
    _cachedHeightByWidth[width] = adaptiveSize;
    size.value = adaptiveSize;
    if (_pacer.isBusy(adUnitId)) AdManager.logBanner(_format, 'queued');
    final turn = await _pacer.acquire(adUnitId);
    if (_disposed) {
      turn.release(failed: false);
      return;
    }
    _unitTurn = turn;
    AdManager.logBanner(_format, 'request', {'width': width, 'height': adaptiveSize.height});
    final ad = BannerAd(
      adUnitId: adUnitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isLoading = false;
          _releaseUnitTurn(failed: false);
          AdManager.logBanner(_format, 'loaded', {
            'responseId': ad.responseInfo?.responseId,
            'adapter': ad.responseInfo?.mediationAdapterClassName,
          });
          if (!_disposed) loaded.value = true;
        },
        onAdFailedToLoad: (ad, error) {
          AdManager.logBannerError(_format, 'failedToLoad', error);
          _releaseUnitTurn(failed: true);
          // A failed banner ad instance cannot be reloaded - it must be
          // discarded and replaced with a fresh instance for the retry.
          ad.dispose();
          _ad = null;
          _isLoading = false;
          if (_disposed) return;
          loaded.value = false;
          _scheduleRetry(width);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _scheduleRetry(int width) {
    if (_retried) return;
    _retried = true;
    Future.delayed(_retryDelay, () {
      if (!_disposed) load(width);
    });
  }

  void _releaseUnitTurn({required bool failed}) {
    _unitTurn?.release(failed: failed);
    _unitTurn = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // A disposed in-flight ad never reports back; free the unit now.
    _releaseUnitTurn(failed: false);
    _ad?.dispose();
    _ad = null;
    loaded.dispose();
    size.dispose();
  }
}
