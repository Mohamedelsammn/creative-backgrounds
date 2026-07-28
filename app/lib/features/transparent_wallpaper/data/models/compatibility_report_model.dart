import '../../domain/entities/compatibility_report.dart';

/// Maps the raw `Map` payload from the native `CompatibilityChecker` channel
/// into the domain [CompatibilityReport]. Unknown/malformed values degrade
/// gracefully to the safest interpretation (unsupported / unknown).
class CompatibilityReportModel {
  const CompatibilityReportModel._();

  static CompatibilityReport fromMap(Map<dynamic, dynamic> map) {
    return CompatibilityReport(
      level: _levelFrom(map['supportLevel'] as String?),
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      manufacturer: map['manufacturer'] as String? ?? 'unknown',
      model: map['model'] as String? ?? 'unknown',
      summary: map['summary'] as String? ?? '',
      checks: _checksFrom(map['checks']),
    );
  }

  static TwSupportLevel _levelFrom(String? raw) {
    switch (raw) {
      case 'supported':
        return TwSupportLevel.supported;
      case 'supported_with_warnings':
        return TwSupportLevel.supportedWithWarnings;
      default:
        return TwSupportLevel.unsupported;
    }
  }

  static TwCheckStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'pass':
        return TwCheckStatus.pass;
      case 'warn':
        return TwCheckStatus.warn;
      case 'fail':
        return TwCheckStatus.fail;
      default:
        return TwCheckStatus.unknown;
    }
  }

  static List<TwCompatibilityCheck> _checksFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((c) => TwCompatibilityCheck(
              id: c['id'] as String? ?? '',
              label: c['label'] as String? ?? '',
              status: _statusFrom(c['status'] as String?),
              detail: c['detail'] as String? ?? '',
            ))
        .toList(growable: false);
  }
}
