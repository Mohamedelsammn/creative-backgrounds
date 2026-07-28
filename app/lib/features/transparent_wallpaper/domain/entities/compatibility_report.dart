/// Overall support for the transparent (live rear-camera) wallpaper, as
/// determined natively. Flutter never computes this itself.
enum TwSupportLevel { supported, supportedWithWarnings, unsupported }

/// Outcome of one individual compatibility check.
enum TwCheckStatus { pass, warn, fail, unknown }

/// A single named check within the compatibility report.
class TwCompatibilityCheck {
  const TwCompatibilityCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final TwCheckStatus status;
  final String detail;
}

/// Structured device-support report produced by the native `CompatibilityChecker`.
class CompatibilityReport {
  const CompatibilityReport({
    required this.level,
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
    required this.summary,
    required this.checks,
  });

  final TwSupportLevel level;
  final int sdkInt;
  final String manufacturer;
  final String model;
  final String summary;
  final List<TwCompatibilityCheck> checks;

  /// True unless the feature is hard-blocked on this device.
  bool get isUsable => level != TwSupportLevel.unsupported;

  /// Checks the user may need to act on (warnings + failures).
  List<TwCompatibilityCheck> get actionableChecks => checks
      .where((c) =>
          c.status == TwCheckStatus.warn || c.status == TwCheckStatus.fail)
      .toList(growable: false);

  /// The OEM/manufacturer warning, if any (aggressive background-kill vendors).
  TwCompatibilityCheck? get manufacturerWarning {
    for (final c in checks) {
      if (c.id == 'manufacturer' && c.status == TwCheckStatus.warn) return c;
    }
    return null;
  }
}
