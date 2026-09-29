import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/usecase.dart';

/// Orchestrates app initialization performed on the splash screen.
///
/// Hive boxes and DI are already set up in `main()`; this use case performs the
/// remaining runtime checks (connectivity, and — when a backend is wired —
/// remote config). It never fails hard on connectivity so the app can run
/// offline from cache.
class InitializeAppUseCase implements UseCase<void, NoParams> {
  InitializeAppUseCase(this._networkInfo);

  final NetworkInfo _networkInfo;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    // Connectivity is advisory and must not extend the branding minimum.
    // Run it independently so a slow/broken platform network probe cannot
    // hold Splash after its animation has completed. Offline remains valid.
    unawaited(
      Future<void>(() async {
        try {
          await _networkInfo.isConnected;
        } catch (_) {
          // Best-effort warm-up only.
        }
      }),
    );
    return const Right(null);
  }
}
