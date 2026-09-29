import 'package:creativebackground/features/adblock/data/services/ad_integrity_service.dart';
import 'package:creativebackground/features/review/data/services/review_service.dart';
import 'package:creativebackground/features/splash/presentation/bloc/splash_bloc.dart';
import 'package:creativebackground/features/update/data/datasources/update_policy_remote_datasource.dart';
import 'package:creativebackground/features/update/data/services/app_update_service.dart';
import 'package:creativebackground/injection.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for a DI wiring bug that no unit test could catch.
///
/// Every service test constructs its subject DIRECTLY
/// (`AppUpdateService(fakeDatasource)`), which bypasses `get_it` entirely -
/// so a service registered against an UNRESOLVABLE dependency still passed
/// the whole suite and only surfaced at runtime, on device, as a blank
/// screen:
///
///   throwIfNot (get_it) -> _findFactoryByNameAndType -> injection.dart:133
///
/// (`AppUpdateService(sl())` asked for a bare `Dio`, but only `DioClient` is
/// registered.) These tests resolve the startup-critical types through the
/// REAL container built by `setupDI()`, which is the only place such a
/// mistake is visible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // AppConfig reads dotenv lazily and throws if it was never loaded; an
    // empty map is enough for every registration exercised here.
    dotenv.testLoad(fileInput: '');
    await setupDI();
  });

  test('AppUpdateService resolves - its datasource dependency is registered',
      () {
    expect(sl<AppUpdateService>(), isA<AppUpdateService>());
  });

  test('UpdatePolicyRemoteDatasource resolves with a usable Dio', () {
    expect(
      sl<UpdatePolicyRemoteDatasource>(),
      isA<UpdatePolicyRemoteDatasourceImpl>(),
    );
  });

  test('ReviewService resolves - HiveStorage dependency is registered', () {
    expect(sl<ReviewService>(), isA<ReviewService>());
  });

  test('AdIntegrityService resolves', () {
    expect(sl<AdIntegrityService>(), isA<AdIntegrityService>());
  });

  test('AppUpdateService is a singleton so its policy cache is shared', () {
    expect(identical(sl<AppUpdateService>(), sl<AppUpdateService>()), isTrue);
  });

  test('ReviewService is a singleton so the apply counter is shared', () {
    expect(identical(sl<ReviewService>(), sl<ReviewService>()), isTrue);
  });

  test(
    'SplashBloc resolves - so all three startup gates it depends on are '
    'themselves resolvable through the container',
    () {
      expect(sl<SplashBloc>(), isA<SplashBloc>());
    },
  );
}
