import 'package:equatable/equatable.dart';

/// What the app was able to observe about network interference.
///
/// Ordered from weakest to strongest evidence. Nothing here proves an ad
/// blocker exists - Android exposes no such API - so every value except
/// [requestsBlocked] is a hint, and [unknown] is a first-class, expected
/// outcome rather than an error.
enum AdBlockStatus {
  /// Checks ran and found nothing unusual.
  clear,

  /// A VPN transport is active.
  ///
  /// This is **not** an accusation. Most VPNs are privacy, work or travel
  /// tools that do not filter anything, so this is reported on its own and the
  /// UI must not treat it as "ad blocker detected".
  vpnDetected,

  /// Private DNS points at a resolver whose stated purpose is filtering.
  ///
  /// Stronger than [vpnDetected] but still circumstantial - a filtering
  /// resolver may not block this app in particular.
  dnsSuspicious,

  /// The strongest signal: a request that should have succeeded did not,
  /// while ordinary app traffic works. Something is selectively blocking.
  requestsBlocked,

  /// Detection could not run or returned nothing usable - no platform support,
  /// no connectivity, a probe error. Never treat this as "clear".
  unknown,
}

/// The outcome of one detection pass, with the evidence behind it.
///
/// The individual signals are kept alongside the verdict so the UI can explain
/// *why* rather than asserting a conclusion the user may disagree with.
class AdBlockReport extends Equatable {
  const AdBlockReport({
    required this.status,
    this.vpnActive,
    this.privateDnsHost,
    this.privateDnsFiltering,
    this.probeSucceeded,
  });

  final AdBlockStatus status;

  /// Null when the platform could not tell us.
  final bool? vpnActive;

  /// The configured Private DNS hostname, when one is set and readable.
  final String? privateDnsHost;

  /// Whether [privateDnsHost] matches a known filtering resolver.
  final bool? privateDnsFiltering;

  /// Whether the network reachability probe completed.
  final bool? probeSucceeded;

  /// Detection ran but could not reach a conclusion.
  bool get isUnknown => status == AdBlockStatus.unknown;

  /// True only when there is direct evidence that requests are being blocked.
  ///
  /// Deliberately excludes [AdBlockStatus.vpnDetected] and
  /// [AdBlockStatus.dnsSuspicious]: acting on those would mean accusing users
  /// of blocking ads because they use a VPN, which is usually wrong.
  bool get hasStrongEvidence => status == AdBlockStatus.requestsBlocked;

  static const unknownReport = AdBlockReport(status: AdBlockStatus.unknown);

  @override
  List<Object?> get props => [
        status,
        vpnActive,
        privateDnsHost,
        privateDnsFiltering,
        probeSucceeded,
      ];
}
