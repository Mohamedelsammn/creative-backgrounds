import 'package:creativebackground/core/storage/hive_storage.dart';
import 'package:creativebackground/core/storage/storage_keys.dart';
import 'package:creativebackground/features/adblock/data/services/ad_block_detection_service.dart';
import 'package:creativebackground/features/adblock/data/services/ad_integrity_service.dart';
import 'package:creativebackground/features/adblock/domain/entities/ad_integrity_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The STARTUP integrity pass (`runStartupIntegrityCheck`) is the one that
/// can keep a user off Home, so its false-positive behaviour is what these
/// tests pin down. It reads only immediate OS-level signals - no ad probe,
/// no network round trip - so Splash is never held hostage by ad inventory.
///
/// The governing rule: only a NAMED ad-blocking Private DNS hostname may
/// gate startup. A bare VPN must not, because at this point there is no ad
/// evidence to corroborate it against and a great many users run a VPN with
/// no ad filtering whatsoever (corporate, privacy, WARP, tethering helpers).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('.dart_tool/test_hive_integrity');
    await Hive.openBox(HiveBoxes.settings);
    await Hive.box(HiveBoxes.settings).clear();
  });

  tearDown(() async {
    await Hive.box(HiveBoxes.settings).clear();
    await Hive.close();
  });

  AdIntegrityService build({bool? vpn, String? dns, bool? filtering}) =>
      AdIntegrityService(
        adBlockService: _FakeDetection(
          vpnActive: vpn,
          dnsHost: dns,
          dnsFiltering: filtering,
        ),
        storage: HiveStorage(),
      );

  group('clean network', () {
    test('no VPN and no private DNS -> granted', () async {
      final result = await build(vpn: false).runStartupIntegrityCheck();
      expect(result.isBlocked, isFalse);
      expect(result.reason, AdBlockReason.none);
    });

    test('an ordinary non-filtering private DNS -> granted', () async {
      // Plenty of users point Private DNS at a plain resolver that filters
      // nothing; that must not be mistaken for an ad blocker.
      final result = await build(dns: 'dns.google').runStartupIntegrityCheck();
      expect(result.isBlocked, isFalse);
    });
  });

  group('confirmed ad-blocking private DNS', () {
    for (final host in const [
      'dns.adguard.com',
      'abcdefg.dns.nextdns.io',
      'freedns.controld.com',
      'dns.mullvad.net',
      'dot.blahdns.com',
      'sky.rethinkdns.com',
    ]) {
      test('$host is blocked', () async {
        final result = await build(dns: host).runStartupIntegrityCheck();
        expect(result.isBlocked, isTrue);
        expect(result.reason, AdBlockReason.dnsFilterDetected);
      });
    }

    test('matching is case-insensitive', () async {
      final result =
          await build(dns: 'DNS.AdGuard.COM').runStartupIntegrityCheck();
      expect(result.isBlocked, isTrue);
    });
  });

  group('VPN false-positive protection', () {
    test(
      'a bare active VPN does NOT gate startup - there is no ad evidence at '
      'this stage to corroborate it, and most VPNs filter nothing',
      () async {
        final result = await build(vpn: true).runStartupIntegrityCheck();
        expect(result.isBlocked, isFalse);
        expect(result.reason, AdBlockReason.none);
      },
    );

    test('a VPN together with a filtering DNS is still blocked on the DNS',
        () async {
      final result = await build(vpn: true, dns: 'dns.adguard.com')
          .runStartupIntegrityCheck();
      expect(result.isBlocked, isTrue);
      expect(result.reason, AdBlockReason.dnsFilterDetected);
    });
  });

  group('indeterminate / failure signals', () {
    test('null signals (native channel unavailable) -> granted', () async {
      final result = await build().runStartupIntegrityCheck();
      expect(result.isBlocked, isFalse);
    });

    test('a throwing detection service -> granted, never an exception',
        () async {
      final service = AdIntegrityService(
        adBlockService: _ThrowingDetection(),
        storage: HiveStorage(),
      );
      final result = await service.runStartupIntegrityCheck();
      expect(result.isBlocked, isFalse);
    });

    test('offline is never reported as ad blocking', () async {
      // Offline shows up as absent/indeterminate signals here, not as a
      // filtering DNS hostname - so it can only ever resolve to granted.
      final result = await build(vpn: false, dns: null)
          .runStartupIntegrityCheck();
      expect(result.isBlocked, isFalse);
    });
  });

  test('the startup pass is fast - it performs no ad or network probe',
      () async {
    final stopwatch = Stopwatch()..start();
    await build(vpn: false).runStartupIntegrityCheck();
    stopwatch.stop();
    // Generous bound; the point is that it cannot be waiting on the 10s ad
    // probe or the 4s connectivity lookup used by the full pass.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}

class _FakeDetection extends AdBlockDetectionService {
  _FakeDetection({this.vpnActive, this.dnsHost, this.dnsFiltering});

  final bool? vpnActive;
  final String? dnsHost;
  final bool? dnsFiltering;

  @override
  Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})>
      readVpnAndDnsSignals() async => (
        vpnActive: vpnActive,
        dnsHost: dnsHost,
        dnsFiltering: dnsFiltering,
      );
}

class _ThrowingDetection extends AdBlockDetectionService {
  @override
  Future<({bool? vpnActive, String? dnsHost, bool? dnsFiltering})>
      readVpnAndDnsSignals() async => throw Exception('channel missing');
}
