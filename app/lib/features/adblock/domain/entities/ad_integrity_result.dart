/// Outcome of an `AdIntegrityService` startup check.
enum AdIntegrityStatus { granted, blocked }

/// The specific signal that caused a [AdIntegrityStatus.blocked] result.
/// Ordered by precedence: a VPN finding is reported before a DNS finding,
/// which is reported before persistent ad-network blocking.
///
/// [adsFailedToLoad] is NOT triggered by a single failed/no-fill ad
/// request - NO_FILL, network hiccups, and other transient load failures are
/// normal AdMob behavior and never block a user on their own. It only fires
/// once several consecutive sessions have shown every ad request failing
/// specifically with NETWORK_ERROR while the device's general internet
/// connectivity was confirmed healthy - the pattern produced by a DNS
/// sinkhole or firewall rule that targets ad domains specifically, as
/// opposed to a transient blip.
enum AdBlockReason { none, vpnDetected, dnsFilterDetected, adsFailedToLoad }

/// Result of one integrity check pass, including the raw diagnostic lines
/// logged during the run (debug builds only).
class AdIntegrityResult {
  const AdIntegrityResult({
    required this.status,
    required this.reason,
    required this.diagnostics,
  });

  final AdIntegrityStatus status;
  final AdBlockReason reason;
  final List<String> diagnostics;

  bool get isBlocked => status == AdIntegrityStatus.blocked;
}
