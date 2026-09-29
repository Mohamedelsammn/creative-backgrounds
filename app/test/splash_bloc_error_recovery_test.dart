import 'package:creativebackground/core/network/network_info.dart';
import 'package:creativebackground/features/adblock/data/services/ad_integrity_service.dart';
import 'package:creativebackground/features/adblock/domain/entities/ad_integrity_result.dart';
import 'package:creativebackground/features/splash/domain/usecases/initialize_app_usecase.dart';
import 'package:creativebackground/features/splash/presentation/bloc/splash_bloc.dart';
import 'package:creativebackground/features/update/data/datasources/update_policy_remote_datasource.dart';
import 'package:creativebackground/features/update/data/services/app_update_service.dart';
import 'package:creativebackground/features/update/domain/entities/update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test: `SplashBloc` must reach a TERMINAL state (SplashError,
/// specifically) no matter what throws during startup - it must never sit in
/// SplashLoading forever, since that is indistinguishable from "stuck on the
/// splash screen" to the user. Every step already guards its own known
/// failure modes (isUpdateRequired/runIntegrityCheck both catch internally,
/// the ad probe has its own timeout) - this covers the outer boundary added
/// for anything unforeseen that still manages to throw past those guards.
void main() {
  group('SplashBloc reaches SplashError instead of hanging when a step '
      'throws unexpectedly', () {
    test('an update-check failure that escapes its own guard still resolves '
        'to SplashError, not an indefinite SplashLoading', () async {
      final bloc = SplashBloc(
        InitializeAppUseCase(_FakeNetworkInfo()),
        AdIntegrityService(),
        _ThrowingAppUpdateService(),
      );

      bloc.add(const SplashStarted());
      await bloc.stream
          .firstWhere((s) => s is! SplashInitial && s is! SplashLoading)
          .timeout(const Duration(seconds: 5));

      expect(bloc.state, isA<SplashError>());
    });

    test('an integrity-check failure that escapes its own guard still '
        'resolves to SplashError, not an indefinite SplashLoading', () async {
      final bloc = SplashBloc(
        InitializeAppUseCase(_FakeNetworkInfo()),
        _ThrowingAdIntegrityService(),
        AppUpdateService(_NullPolicyDatasource()),
      );

      bloc.add(const SplashStarted());
      await bloc.stream
          .firstWhere((s) => s is! SplashInitial && s is! SplashLoading)
          .timeout(const Duration(seconds: 5));

      expect(bloc.state, isA<SplashError>());
    });

    test(
      'SplashError is recoverable - dispatching SplashStarted again '
      'after a failure re-runs startup and can still reach SplashComplete',
      () async {
        final updateService = _FlakyOnceAppUpdateService();
        final bloc = SplashBloc(
          InitializeAppUseCase(_FakeNetworkInfo()),
          _GrantedAdIntegrityService(),
          updateService,
        );

        bloc.add(const SplashStarted());
        await bloc.stream
            .firstWhere((s) => s is! SplashInitial && s is! SplashLoading)
            .timeout(const Duration(seconds: 5));
        expect(
          bloc.state,
          isA<SplashError>(),
          reason: 'sanity check: the first attempt does fail',
        );

        // Retry, exactly as the error dialog's "Retry" button does.
        bloc.add(const SplashStarted());
        await bloc.stream
            .firstWhere((s) => s is! SplashLoading)
            .timeout(const Duration(seconds: 5));

        expect(
          bloc.state,
          isNot(isA<SplashError>()),
          reason:
              'a retry must be able to succeed once the transient '
              'failure is gone, not be permanently wedged in SplashError',
        );
      },
    );
  });
}

/// Reports "no policy available", i.e. the fail-open path - these tests are
/// about SplashBloc's error handling, not about update policy content.
class _NullPolicyDatasource implements UpdatePolicyRemoteDatasource {
  @override
  Future<UpdatePolicy?> fetchPolicy() async => null;
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _ThrowingAppUpdateService extends AppUpdateService {
  _ThrowingAppUpdateService() : super(_NullPolicyDatasource());

  @override
  Future<bool> isUpdateRequired({bool forceRefresh = false}) async {
    throw StateError('simulated failure escaping isUpdateRequired\'s guard');
  }
}

class _FlakyOnceAppUpdateService extends AppUpdateService {
  _FlakyOnceAppUpdateService() : super(_NullPolicyDatasource());

  var _calls = 0;

  @override
  Future<bool> isUpdateRequired({bool forceRefresh = false}) async {
    _calls++;
    if (_calls == 1) {
      throw StateError('simulated transient failure on the first attempt');
    }
    return false;
  }
}

class _ThrowingAdIntegrityService extends AdIntegrityService {
  @override
  Future<AdIntegrityResult> runStartupIntegrityCheck() async {
    throw StateError('simulated failure escaping startup integrity check');
  }
}

/// Never probes a real ad (which would need a live AdMob platform channel
/// unavailable in a plain flutter_test environment) - just reports "not
/// blocked", so this stands in for the happy path once the OTHER dependency
/// under test has already failed once and is being retried.
class _GrantedAdIntegrityService extends AdIntegrityService {
  @override
  Future<AdIntegrityResult> runStartupIntegrityCheck() async =>
      const AdIntegrityResult(
        status: AdIntegrityStatus.granted,
        reason: AdBlockReason.none,
        diagnostics: [],
      );
}
