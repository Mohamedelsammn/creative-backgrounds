import 'package:flutter/material.dart';

import '../../../core/ads/ad_manager.dart';
import '../domain/entities/ad_integrity_result.dart';
import '../data/services/ad_integrity_service.dart';
import 'pages/ad_blocking_detected_screen.dart';

/// Owns the ads-blocked screen: shows it at most once at a time, keeps every
/// full-screen ad off while it is up, and runs the full reference check once
/// per launch after Home appears.
///
/// Splash only runs the instant local Private DNS check, so startup never
/// waits on an ad probe. The full check (ad probe, cross-session
/// NETWORK_ERROR streak, VPN corroboration) runs here in the background
/// instead; if it confirms blocking, the blocker replaces Home.
class AdIntegrityGate {
  AdIntegrityGate({
    AdIntegrityService Function()? service,
    AdManager? ads,
  }) : _service = service ?? AdIntegrityService.new,
       _ads = ads;

  static final AdIntegrityGate instance = AdIntegrityGate();

  final AdIntegrityService Function() _service;
  final AdManager? _ads;

  AdManager get _adManager => _ads ?? AdManager.instance;

  bool _postHomeCheckStarted = false;
  bool _showing = false;

  /// Whether the ads-blocked screen is on screen.
  bool get isShowing => _showing;

  /// This launch already passed a full check (a successful Retry), so the
  /// post-Home check is not needed again.
  void markVerified() => _postHomeCheckStarted = true;

  /// Runs the full integrity check once per launch, without blocking Home.
  /// Returns the result, or null when skipped or the check threw.
  Future<AdIntegrityResult?> runPostHomeCheck(BuildContext context) async {
    if (_postHomeCheckStarted) return null;
    _postHomeCheckStarted = true;
    final AdIntegrityResult result;
    try {
      result = await _service().runIntegrityCheck();
    } catch (_) {
      return null;
    }
    AdManager.logBanner('AdIntegrity', 'postHomeCheck', {
      'blocked': result.isBlocked,
      'reason': result.reason.name,
    });
    if (result.isBlocked && context.mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      present(navigator, onCleared: navigator.pop);
    }
    return result;
  }

  /// Pushes the ads-blocked screen unless it is already showing. Returns
  /// whether it was pushed. [onCleared] runs once a Retry comes back clear.
  bool present(NavigatorState navigator, {required VoidCallback onCleared}) {
    if (_showing) return false;
    _showing = true;
    _adManager.setFullScreenAdsSuppressed(true);
    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (_) => AdBlockingDetectedScreen(
              onRetrySucceeded: () {
                _clear();
                markVerified();
                onCleared();
              },
            ),
          ),
        )
        // Removed by other navigation (e.g. the router replacing the
        // stack): never leave ads suppressed or a stale "showing" flag.
        .whenComplete(_clear);
    return true;
  }

  void _clear() {
    if (!_showing) return;
    _showing = false;
    _adManager.setFullScreenAdsSuppressed(false);
  }

  @visibleForTesting
  void debugReset() {
    _postHomeCheckStarted = false;
    _showing = false;
  }
}
