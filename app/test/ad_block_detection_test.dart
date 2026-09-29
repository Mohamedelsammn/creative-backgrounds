import 'package:creativebackground/features/adblock/domain/entities/ad_block_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the ad-block detection contract.
///
/// The point of these is the *policy*, not the plumbing: the feature must never
/// accuse a user of blocking ads because they happen to use a VPN, and must
/// treat "could not tell" as its own outcome rather than as "clear".
void main() {
  group('evidence strength', () {
    test('only a failed request probe counts as strong evidence', () {
      const blocked = AdBlockReport(
        status: AdBlockStatus.requestsBlocked,
        probeSucceeded: false,
      );
      expect(blocked.hasStrongEvidence, isTrue);
    });

    test('a VPN alone is NOT strong evidence of ad blocking', () {
      // Most VPNs filter nothing. Acting on this would wrongly accuse a large
      // share of ordinary users.
      const vpn = AdBlockReport(status: AdBlockStatus.vpnDetected, vpnActive: true);
      expect(vpn.hasStrongEvidence, isFalse);
      expect(vpn.isUnknown, isFalse);
    });

    test('filtering DNS is a hint, not proof', () {
      const dns = AdBlockReport(
        status: AdBlockStatus.dnsSuspicious,
        privateDnsHost: 'dns.adguard.com',
        privateDnsFiltering: true,
      );
      expect(dns.hasStrongEvidence, isFalse);
    });

    test('clear is not strong evidence of anything', () {
      const clear = AdBlockReport(status: AdBlockStatus.clear);
      expect(clear.hasStrongEvidence, isFalse);
      expect(clear.isUnknown, isFalse);
    });
  });

  group('unknown handling', () {
    test('unknown is distinct from clear', () {
      const unknown = AdBlockReport(status: AdBlockStatus.unknown);
      const clear = AdBlockReport(status: AdBlockStatus.clear);

      expect(unknown.isUnknown, isTrue);
      expect(clear.isUnknown, isFalse);
      expect(
        unknown,
        isNot(equals(clear)),
        reason: 'treating "cannot determine" as "nothing found" would silently '
            'report success on devices where detection never ran',
      );
    });

    test('the shared unknown report carries no false signals', () {
      const report = AdBlockReport.unknownReport;
      expect(report.status, AdBlockStatus.unknown);
      expect(report.vpnActive, isNull);
      expect(report.privateDnsHost, isNull);
      expect(report.privateDnsFiltering, isNull);
      expect(report.hasStrongEvidence, isFalse);
    });

    test('null signals mean "could not determine", not "false"', () {
      const report = AdBlockReport(status: AdBlockStatus.unknown);
      // A caller must never read `vpnActive == null` as "no VPN".
      expect(report.vpnActive, isNot(false));
      expect(report.vpnActive, isNull);
    });
  });

  group('report equality', () {
    test('reports with the same evidence are equal', () {
      const a = AdBlockReport(status: AdBlockStatus.vpnDetected, vpnActive: true);
      const b = AdBlockReport(status: AdBlockStatus.vpnDetected, vpnActive: true);
      expect(a, equals(b));
    });

    test('the same status with different evidence is not equal', () {
      const a = AdBlockReport(status: AdBlockStatus.unknown, vpnActive: true);
      const b = AdBlockReport(status: AdBlockStatus.unknown, vpnActive: null);
      expect(a, isNot(equals(b)));
    });
  });

  test('every status is reachable and distinct', () {
    expect(AdBlockStatus.values.toSet(), hasLength(AdBlockStatus.values.length));
    expect(AdBlockStatus.values, contains(AdBlockStatus.unknown));
    expect(AdBlockStatus.values, contains(AdBlockStatus.requestsBlocked));
  });
}
