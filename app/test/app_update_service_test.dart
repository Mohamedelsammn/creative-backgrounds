import 'package:creativebackground/features/update/data/datasources/update_policy_remote_datasource.dart';
import 'package:creativebackground/features/update/data/services/app_update_service.dart';
import 'package:creativebackground/features/update/domain/entities/update_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// `AppUpdateService` compares the installed Android **versionCode**
/// (`PackageInfo.buildNumber`) against a REMOTELY configured
/// `minimumSupportedBuild`.
///
/// The single most important property under test is the FAIL-SAFE: any
/// config problem (offline, timeout, malformed, unset URL) must resolve to
/// "update not required". Locking the entire install base out of a working
/// app because a config host blipped is a far worse outcome than missing one
/// force-update cycle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setInstalledBuild(String buildNumber) {
    PackageInfo.setMockInitialValues(
      appName: 'Creative Backgrounds',
      packageName: 'com.backgrounds.trend4k',
      version: '1.0.0',
      buildNumber: buildNumber,
      buildSignature: '',
    );
  }

  group('build-number comparison', () {
    test('installed BELOW minimum is blocked', () async {
      setInstalledBuild('45');
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 47)),
      );
      expect(await service.isUpdateRequired(), isTrue);
    });

    test('installed EQUAL to minimum is allowed', () async {
      setInstalledBuild('47');
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 47)),
      );
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('installed ABOVE minimum is allowed', () async {
      setInstalledBuild('48');
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 47)),
      );
      expect(await service.isUpdateRequired(), isFalse);
    });

    test(
      'numeric comparison, not string: build 100 beats minimum 99 '
      '(string ordering would wrongly block it)',
      () async {
        setInstalledBuild('100');
        final service = AppUpdateService(
          _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 99)),
        );
        expect(await service.isUpdateRequired(), isFalse);
      },
    );
  });

  group('remote kill switch', () {
    test('forceUpdate:false makes the gate inert even below the minimum',
        () async {
      setInstalledBuild('45');
      final service = AppUpdateService(
        _FakeDatasource(
          const UpdatePolicy(minimumSupportedBuild: 47, forceUpdate: false),
        ),
      );
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('a minimum of 0 never blocks anyone', () async {
      setInstalledBuild('1');
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 0)),
      );
      expect(await service.isUpdateRequired(), isFalse);
    });
  });

  group('fail-safe', () {
    test('config unreachable (null) does NOT block', () async {
      setInstalledBuild('1');
      final service = AppUpdateService(_FakeDatasource(null));
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('a throwing datasource does NOT block', () async {
      setInstalledBuild('1');
      final service = AppUpdateService(_ThrowingDatasource());
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('a timing-out datasource does NOT block', () async {
      setInstalledBuild('1');
      final service = AppUpdateService(_TimeoutDatasource());
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('a non-integer installed build number does NOT block', () async {
      setInstalledBuild('not-a-number');
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 9999)),
      );
      expect(await service.isUpdateRequired(), isFalse);
    });

    test('UpdatePolicy.failOpen can never require an update', () {
      expect(UpdatePolicy.failOpen.isUpdateRequiredFor(0), isFalse);
      expect(UpdatePolicy.failOpen.isUpdateRequiredFor(1), isFalse);
    });
  });

  group('policy caching / resume re-check', () {
    test('the policy is fetched once and cached across calls', () async {
      setInstalledBuild('45');
      final ds = _FakeDatasource(
        const UpdatePolicy(minimumSupportedBuild: 47),
      );
      final service = AppUpdateService(ds);
      await service.isUpdateRequired();
      await service.isUpdateRequired();
      expect(ds.fetchCount, 1);
    });

    test('forceRefresh refetches - so a resume after updating re-evaluates',
        () async {
      setInstalledBuild('45');
      final ds = _FakeDatasource(
        const UpdatePolicy(minimumSupportedBuild: 47),
      );
      final service = AppUpdateService(ds);
      expect(await service.isUpdateRequired(), isTrue);

      // User updated while away: new build now satisfies the same policy.
      setInstalledBuild('47');
      expect(await service.isUpdateRequired(forceRefresh: true), isFalse);
      expect(ds.fetchCount, 2);
    });
  });

  group('store url + message', () {
    test('policy storeUrl wins over the compiled-in listing', () async {
      final service = AppUpdateService(
        _FakeDatasource(
          const UpdatePolicy(
            minimumSupportedBuild: 1,
            storeUrl: 'https://play.google.com/store/apps/details?id=custom',
          ),
        ),
      );
      expect(await service.storeUrl(), contains('id=custom'));
    });

    test('falls back to the Play listing when the policy has no storeUrl',
        () async {
      final service = AppUpdateService(
        _FakeDatasource(const UpdatePolicy(minimumSupportedBuild: 1)),
      );
      expect(await service.storeUrl(), contains('com.backgrounds.trend4k'));
    });

    test('localized remote message is returned per language', () async {
      final service = AppUpdateService(
        _FakeDatasource(
          const UpdatePolicy(
            minimumSupportedBuild: 1,
            messages: {'en': 'Please update.', 'ar': 'يجب التحديث.'},
          ),
        ),
      );
      expect(await service.remoteMessage('en'), 'Please update.');
      expect(await service.remoteMessage('ar'), 'يجب التحديث.');
      // Unknown locale -> null, so the UI uses its own bundled copy.
      expect(await service.remoteMessage('fr'), isNull);
    });
  });
}

class _FakeDatasource implements UpdatePolicyRemoteDatasource {
  _FakeDatasource(this._policy);
  final UpdatePolicy? _policy;
  int fetchCount = 0;

  @override
  Future<UpdatePolicy?> fetchPolicy() async {
    fetchCount++;
    return _policy;
  }
}

class _ThrowingDatasource implements UpdatePolicyRemoteDatasource {
  @override
  Future<UpdatePolicy?> fetchPolicy() async =>
      throw Exception('network down');
}

class _TimeoutDatasource implements UpdatePolicyRemoteDatasource {
  /// Mirrors what the real datasource does on timeout: it swallows the
  /// timeout internally and reports null rather than hanging its caller.
  @override
  Future<UpdatePolicy?> fetchPolicy() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return null;
  }
}
