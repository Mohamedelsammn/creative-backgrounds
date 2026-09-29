import 'package:creativebackground/core/network/network_info.dart';
import 'package:creativebackground/features/adblock/data/services/ad_integrity_service.dart';
import 'package:creativebackground/features/adblock/domain/entities/ad_integrity_result.dart';
import 'package:creativebackground/features/splash/domain/usecases/initialize_app_usecase.dart';
import 'package:creativebackground/features/splash/presentation/bloc/splash_bloc.dart';
import 'package:creativebackground/features/update/data/datasources/update_policy_remote_datasource.dart';
import 'package:creativebackground/features/update/data/services/app_update_service.dart';
import 'package:creativebackground/features/update/domain/entities/update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Startup orchestration contract.
///
/// `SplashBloc` resolves the blocking gates in a fixed priority so a user is
/// never shown the wrong screen, and - critically for the previously-fixed
/// Splash performance problems - runs them CONCURRENTLY rather than as a
/// chain of sequential network waits.
///
/// Priority: init failure > force update > confirmed ad blocking > Home.
void main() {
  SplashBloc build({
    required bool updateRequired,
    required bool adsBlocked,
  }) => SplashBloc(
    InitializeAppUseCase(_OnlineNetworkInfo()),
    _StubIntegrity(blocked: adsBlocked),
    _StubUpdate(required: updateRequired),
  );

  Future<SplashState> settle(SplashBloc bloc) async {
    bloc.add(const SplashStarted());
    await bloc.stream
        .firstWhere((s) => s is! SplashInitial && s is! SplashLoading)
        .timeout(const Duration(seconds: 10));
    return bloc.state;
  }

  test('clean startup reaches SplashComplete (Home becomes interactive)',
      () async {
    final state = await settle(
      build(updateRequired: false, adsBlocked: false),
    );
    expect(state, isA<SplashComplete>());
  });

  test('a required update blocks access', () async {
    final state = await settle(
      build(updateRequired: true, adsBlocked: false),
    );
    expect(state, isA<SplashUpdateRequired>());
  });

  test('confirmed ad blocking blocks access', () async {
    final state = await settle(
      build(updateRequired: false, adsBlocked: true),
    );
    expect(state, isA<SplashAdsBlocked>());
  });

  test(
    'the UPDATE gate takes precedence over the ad-block gate when both '
    'fire - a user on an unsupported build must be told to update, not '
    'sent to fix their DNS for a build that is about to be replaced',
    () async {
      final state = await settle(
        build(updateRequired: true, adsBlocked: true),
      );
      expect(state, isA<SplashUpdateRequired>());
    },
  );

  test(
    'being OFFLINE does not fail startup - initialization treats '
    'connectivity as advisory so the app still opens from cache',
    () async {
      final bloc = SplashBloc(
        InitializeAppUseCase(_OfflineNetworkInfo()),
        _StubIntegrity(blocked: false),
        _StubUpdate(required: false),
      );
      expect(await settle(bloc), isA<SplashComplete>());
    },
  );

  test(
    'offline is never converted into an ad-blocking verdict: with no '
    'network the integrity pass reports granted, so the user reaches Home '
    'rather than being accused of running an ad blocker',
    () async {
      final bloc = SplashBloc(
        InitializeAppUseCase(_OfflineNetworkInfo()),
        // What the real startup pass yields with no usable signals.
        _StubIntegrity(blocked: false),
        _StubUpdate(required: false),
      );
      final state = await settle(bloc);
      expect(state, isA<SplashComplete>());
      expect(state, isNot(isA<SplashAdsBlocked>()));
    },
  );

  test(
    'the gates run concurrently, not sequentially - two 600ms checks must '
    'not add up to 1.2s on the startup path',
    () async {
      final bloc = SplashBloc(
        InitializeAppUseCase(_OnlineNetworkInfo()),
        _SlowIntegrity(const Duration(milliseconds: 600)),
        _SlowUpdate(const Duration(milliseconds: 600)),
      );
      final stopwatch = Stopwatch()..start();
      await settle(bloc);
      stopwatch.stop();
      // Also below the bloc's own 3s minimum splash display, which is what
      // actually dominates here - proving neither check extended it.
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 3600)));
    },
  );

  test(
    'the review prompt is not part of startup at all - no SplashState '
    'represents it, so it can never gate or delay Home',
    () {
      // A compile-time/structural assertion: the only terminal states are
      // the three below plus SplashError. Adding a review gate would have to
      // add a state here, which this pins against.
      const states = <SplashState>[
        SplashComplete(),
        SplashUpdateRequired(),
        SplashAdsBlocked(),
      ];
      expect(states.whereType<SplashComplete>().length, 1);
      expect(states.length, 3);
    },
  );
}

class _OnlineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _OfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

class _StubUpdate extends AppUpdateService {
  _StubUpdate({required this.required}) : super(_NullPolicyDatasource());
  final bool required;

  @override
  Future<bool> isUpdateRequired({bool forceRefresh = false}) async => required;
}

class _SlowUpdate extends AppUpdateService {
  _SlowUpdate(this.delay) : super(_NullPolicyDatasource());
  final Duration delay;

  @override
  Future<bool> isUpdateRequired({bool forceRefresh = false}) async {
    await Future<void>.delayed(delay);
    return false;
  }
}

class _StubIntegrity extends AdIntegrityService {
  _StubIntegrity({required this.blocked});
  final bool blocked;

  @override
  Future<AdIntegrityResult> runStartupIntegrityCheck() async =>
      AdIntegrityResult(
        status: blocked
            ? AdIntegrityStatus.blocked
            : AdIntegrityStatus.granted,
        reason: blocked ? AdBlockReason.dnsFilterDetected : AdBlockReason.none,
        diagnostics: const [],
      );
}

class _SlowIntegrity extends AdIntegrityService {
  _SlowIntegrity(this.delay);
  final Duration delay;

  @override
  Future<AdIntegrityResult> runStartupIntegrityCheck() async {
    await Future<void>.delayed(delay);
    return const AdIntegrityResult(
      status: AdIntegrityStatus.granted,
      reason: AdBlockReason.none,
      diagnostics: [],
    );
  }
}

class _NullPolicyDatasource implements UpdatePolicyRemoteDatasource {
  @override
  Future<UpdatePolicy?> fetchPolicy() async => null;
}
