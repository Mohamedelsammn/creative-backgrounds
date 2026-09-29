import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../adblock/data/services/ad_integrity_service.dart';
import '../../../adblock/domain/entities/ad_integrity_result.dart';
import '../../../update/data/services/app_update_service.dart';
import '../../domain/usecases/initialize_app_usecase.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc(this._initializeApp, this._adIntegrity, this._appUpdate)
    : super(const SplashInitial()) {
    on<SplashStarted>(_onStarted);
  }

  final InitializeAppUseCase _initializeApp;
  final AdIntegrityService _adIntegrity;
  final AppUpdateService _appUpdate;

  /// Minimum splash duration for branding, even if init finishes sooner.
  static const _minDisplay = Duration(seconds: 3);

  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashLoading());
    try {
      final results = await Future.wait([
        _initializeApp(const NoParams()),
        _appUpdate.isUpdateRequired(),
        _adIntegrity.runStartupIntegrityCheck(),
        Future.delayed(_minDisplay),
      ]);
      final initResult = results.first;
      if (initResult.isLeft()) {
        initResult.fold(
          (failure) => emit(SplashError(failure.message)),
          (_) {},
        );
        return;
      }

      // Mandatory updates stay ahead of the lightweight local integrity
      // signal; neither waits on ad inventory or an ad-network round trip.
      if (results[1] as bool) {
        emit(const SplashUpdateRequired());
        return;
      }

      final integrity = results[2] as AdIntegrityResult;
      emit(
        integrity.isBlocked ? const SplashAdsBlocked() : const SplashComplete(),
      );
    } catch (e) {
      // Every step above already guards its own known failure modes
      // (isUpdateRequired/startup integrity both catch internally), but this
      // is the outer boundary that
      // guarantees SplashBloc reaches a terminal state no matter what -
      // without it, any unforeseen exception here (e.g. a Hive read/write
      // failure deep in the integrity check) would propagate uncaught and
      // leave the bloc sitting in SplashLoading forever, which is
      // indistinguishable from the app being permanently stuck on Splash.
      emit(SplashError(e.toString()));
    }
  }
}
