/// Pure decision logic for when full-screen ads may show. No SDK calls, so it
/// is unit-testable; `AdManager` owns the ads and asks these for permission.
library;

import 'dart:async';

/// The full-screen formats that must never overlap one another.
enum FullScreenAdFormat { appOpen, interstitial, rewarded }

/// Only one full-screen ad at a time, and never the same show twice.
class FullScreenAdGate {
  FullScreenAdFormat? _showing;

  bool get isShowing => _showing != null;
  FullScreenAdFormat? get showing => _showing;

  /// Claims the screen for [format]. False if any full-screen ad is showing.
  bool tryAcquire(FullScreenAdFormat format) {
    if (_showing != null) return false;
    _showing = format;
    return true;
  }

  /// Frees the screen. A release from a format that does not hold it is
  /// ignored, so a late duplicate callback cannot free another ad's claim.
  void release(FullScreenAdFormat format) {
    if (_showing == format) _showing = null;
  }
}

/// Counts successful wallpaper applies; every [every]th one may show an
/// interstitial (applies #3, #6, #9, ...). Failed or cancelled applies are
/// never recorded.
class InterstitialApplyCounter {
  InterstitialApplyCounter({this.every = 3});

  final int every;
  int _successfulApplies = 0;

  int get successfulApplies => _successfulApplies;

  /// Records one successful apply. True when this apply is an eligible one.
  bool recordSuccessfulApply() {
    _successfulApplies++;
    return _successfulApplies % every == 0;
  }
}

/// Paces banner requests per ad unit: one request in flight per unit, and
/// after a failure the next one waits [failureBackoff].
///
/// Without this, Home's in-feed slots (all one unit) requested together and
/// retried together after a No Fill, and the SDK rejected the burst on the
/// phone itself with code 1 "Too many recently failed requests for ad unit
/// ID ... You must wait a few seconds" - requests that never reached AdMob.
class AdUnitRequestPacer {
  AdUnitRequestPacer({this.failureBackoff = const Duration(seconds: 30)});

  final Duration failureBackoff;
  final Map<String, Future<void>> _tail = {};

  /// Whether a request for [unit] is in flight or backing off.
  bool isBusy(String unit) => _tail.containsKey(unit);

  /// Completes when it is this caller's turn to request [unit]. The caller
  /// must [AdUnitTurn.release] the turn when its request finishes.
  Future<AdUnitTurn> acquire(String unit) async {
    final previous = _tail[unit];
    final done = Completer<void>();
    _tail[unit] = done.future;
    if (previous != null) await previous;
    return AdUnitTurn._(this, unit, done);
  }

  void _finish(String unit, Completer<void> done, {required bool failed}) {
    void complete() {
      if (identical(_tail[unit], done.future)) _tail.remove(unit);
      if (!done.isCompleted) done.complete();
    }

    failed ? Future<void>.delayed(failureBackoff, complete) : complete();
  }
}

/// One caller's turn on an ad unit, from [AdUnitRequestPacer.acquire].
class AdUnitTurn {
  AdUnitTurn._(this._pacer, this._unit, this._done);

  final AdUnitRequestPacer _pacer;
  final String _unit;
  final Completer<void> _done;
  bool _released = false;

  /// Ends the turn. After a [failed] request the unit stays blocked for the
  /// backoff. Releasing twice is a no-op.
  void release({required bool failed}) {
    if (_released) return;
    _released = true;
    _pacer._finish(_unit, _done, failed: failed);
  }
}

/// App Open timing rules.
class AppOpenPolicy {
  AppOpenPolicy({
    this.maxAge = const Duration(hours: 4),
    this.minBackground = const Duration(seconds: 30),
    this.coldStartWindow = const Duration(seconds: 8),
  });

  /// App Open ads are valid for four hours after loading.
  final Duration maxAge;

  /// How long the app must have been in the background before a resume may
  /// show an App Open - a quick app switch never does.
  final Duration minBackground;

  /// How long after Home first appears a late-loading App Open may still
  /// show. Past this the user is already browsing, so it waits for a resume.
  final Duration coldStartWindow;

  DateTime? _backgroundedAt;
  bool _suppressNextResume = false;

  bool isExpired(DateTime loadedAt, DateTime now) => now.difference(loadedAt) >= maxAge;

  void onBackgrounded(DateTime now) {
    // Duplicate pause callbacks keep the FIRST moment the app left.
    _backgroundedAt ??= now;
  }

  /// The next resume must not show an App Open - e.g. coming back from the
  /// system wallpaper picker after an Apply.
  void suppressNextResume() => _suppressNextResume = true;

  /// Whether this resume may show an App Open. Consumes the background
  /// timestamp and any suppression, so duplicate resume callbacks can never
  /// show twice.
  bool shouldShowOnResume(DateTime now) {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_suppressNextResume) {
      _suppressNextResume = false;
      return false;
    }
    if (since == null) return false;
    return now.difference(since) >= minBackground;
  }

  bool withinColdStartWindow(DateTime homeReadyAt, DateTime now) =>
      now.difference(homeReadyAt) <= coldStartWindow;
}
