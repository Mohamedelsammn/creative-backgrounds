import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/ad_block_status.dart';

/// Best-effort detection of network interference that could block the app's
/// requests.
///
/// ## Why this is deliberately conservative
///
/// Android has no API that reveals whether an ad blocker is installed, and
/// there is no reliable way to infer one. Three signals are gathered and
/// weighted so the app never accuses a user on weak evidence:
///
/// | signal                       | strength      | verdict on its own      |
/// |------------------------------|---------------|-------------------------|
/// | reachability probe failed    | strong        | [AdBlockStatus.requestsBlocked] |
/// | filtering Private DNS in use | circumstantial| [AdBlockStatus.dnsSuspicious]   |
/// | VPN transport active         | weak          | [AdBlockStatus.vpnDetected]     |
///
/// A VPN on its own is **not** treated as ad blocking - most VPNs filter
/// nothing. It is reported so the UI can mention it, never to gate access.
///
/// Anything that cannot be determined yields [AdBlockStatus.unknown]. This
/// class never throws: a failed detection is a normal outcome, not an error.
class AdBlockDetectionService {
  AdBlockDetectionService({Dio? probeClient})
      : _dio = probeClient ??
            Dio(BaseOptions(
              connectTimeout: _probeTimeout,
              receiveTimeout: _probeTimeout,
              // A blocked request often returns a redirect to a blank page or
              // a 0-byte 200 rather than failing outright, so treat every
              // status as non-throwing and judge the body instead.
              validateStatus: (_) => true,
            ));

  final Dio _dio;

  static const MethodChannel _channel =
      MethodChannel('com.backgrounds.trend4k/adblock');

  static const Duration _probeTimeout = Duration(seconds: 4);

  /// Endpoints used purely to test reachability.
  ///
  /// These are ad/tracker-adjacent hosts that DNS-level blockers commonly sink.
  /// Nothing is read from the response beyond whether it arrived - no content
  /// is parsed, stored, or sent anywhere.
  static const List<String> _probeUrls = [
    'https://googleads.g.doubleclick.net/favicon.ico',
    'https://pagead2.googlesyndication.com/favicon.ico',
  ];

  /// A control endpoint that a blocker has no reason to touch.
  ///
  /// Without this, plain "no internet" would be misreported as blocking.
  static const String _controlUrl =
      'https://creative-backgrounds.arabplus4tech.com/api/v1/public/config';

  /// Reads only the native VPN/private-DNS signals, without running the
  /// reachability probe [detect] also does. Exposed for
  /// `AdIntegrityService`, which runs its own ad-load probe instead of the
  /// generic reachability one - reusing this avoids invoking the native
  /// channel twice for the same underlying signals when both checks run
  /// during the same app session.
  Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})>
      readVpnAndDnsSignals() async {
    final signals = await _readNativeSignals();
    return (
      vpnActive: signals['vpnActive'] as bool?,
      dnsHost: signals['privateDnsHost'] as String?,
      dnsFiltering: signals['privateDnsFiltering'] as bool?,
    );
  }

  /// Runs one detection pass. Never throws.
  Future<AdBlockReport> detect() async {
    final signals = await _readNativeSignals();

    // No platform signals AND no probe result means we genuinely cannot tell.
    final vpnActive = signals['vpnActive'] as bool?;
    final dnsHost = signals['privateDnsHost'] as String?;
    final dnsFiltering = signals['privateDnsFiltering'] as bool?;

    final probe = await _probeReachability();

    // Strongest evidence first: the control host answered but the ad hosts did
    // not. That asymmetry is what distinguishes filtering from being offline.
    if (probe == _ProbeOutcome.blocked) {
      return AdBlockReport(
        status: AdBlockStatus.requestsBlocked,
        vpnActive: vpnActive,
        privateDnsHost: dnsHost,
        privateDnsFiltering: dnsFiltering,
        probeSucceeded: false,
      );
    }

    // Offline: nothing can be concluded about filtering.
    if (probe == _ProbeOutcome.offline) {
      return AdBlockReport(
        status: AdBlockStatus.unknown,
        vpnActive: vpnActive,
        privateDnsHost: dnsHost,
        privateDnsFiltering: dnsFiltering,
        probeSucceeded: false,
      );
    }

    if (dnsFiltering == true) {
      return AdBlockReport(
        status: AdBlockStatus.dnsSuspicious,
        vpnActive: vpnActive,
        privateDnsHost: dnsHost,
        privateDnsFiltering: true,
        probeSucceeded: probe == _ProbeOutcome.reachable,
      );
    }

    if (vpnActive == true) {
      return AdBlockReport(
        status: AdBlockStatus.vpnDetected,
        vpnActive: true,
        privateDnsHost: dnsHost,
        privateDnsFiltering: dnsFiltering,
        probeSucceeded: probe == _ProbeOutcome.reachable,
      );
    }

    // Nothing observable, and the probe actually completed.
    if (probe == _ProbeOutcome.reachable) {
      return AdBlockReport(
        status: AdBlockStatus.clear,
        vpnActive: vpnActive,
        privateDnsHost: dnsHost,
        privateDnsFiltering: dnsFiltering,
        probeSucceeded: true,
      );
    }

    return AdBlockReport(
      status: AdBlockStatus.unknown,
      vpnActive: vpnActive,
      privateDnsHost: dnsHost,
      privateDnsFiltering: dnsFiltering,
      probeSucceeded: null,
    );
  }

  /// Reads the locally visible network configuration from the platform.
  /// Returns an empty map on any failure, which callers read as "unknown".
  Future<Map<String, dynamic>> _readNativeSignals() async {
    try {
      final raw =
          await _channel.invokeMapMethod<dynamic, dynamic>('inspectNetwork');
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry('$k', v));
    } on MissingPluginException {
      // Non-Android platform or the handler is not registered - expected, not
      // an error.
      return const {};
    } catch (e) {
      developer.log('native probe failed: $e', name: 'AdBlock');
      return const {};
    }
  }

  /// Compares ad-host reachability against a control host.
  Future<_ProbeOutcome> _probeReachability() async {
    // The control request decides whether we are online at all. If it fails,
    // ad hosts failing proves nothing.
    final controlOk = await _canReach(_controlUrl);
    if (!controlOk) return _ProbeOutcome.offline;

    for (final url in _probeUrls) {
      if (await _canReach(url)) {
        // At least one ad host is reachable - nothing is being sinkholed.
        return _ProbeOutcome.reachable;
      }
    }
    // Online, yet no ad host answered.
    return _ProbeOutcome.blocked;
  }

  Future<bool> _canReach(String url) async {
    try {
      final res = await _dio.head<void>(url);
      final code = res.statusCode ?? 0;
      // Any real HTTP answer counts as reachable. DNS sinkholes typically
      // fail to connect rather than replying, which lands in the catch below.
      return code > 0 && code < 500;
    } catch (_) {
      return false;
    }
  }
}

/// Outcome of the reachability comparison.
enum _ProbeOutcome {
  /// Ad hosts answered - nothing is sinkholing them.
  reachable,

  /// Control host answered but ad hosts did not.
  blocked,

  /// Control host failed: the device is offline or the API is down.
  offline,
}
