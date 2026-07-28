import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/initialize_app_usecase.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc(this._initializeApp) : super(const SplashInitial()) {
    on<SplashStarted>(_onStarted);
  }

  final InitializeAppUseCase _initializeApp;

  /// Minimum splash duration for branding, even if init finishes sooner.
  static const _minDisplay = Duration(milliseconds: 1500);

  Future<void> _onStarted(SplashStarted event, Emitter<SplashState> emit) async {
    emit(const SplashLoading());
    final results = await Future.wait([
      _initializeApp(const NoParams()),
      Future.delayed(_minDisplay),
    ]);
    final initResult = results.first;
    initResult.fold(
      (failure) => emit(SplashError(failure.message)),
      (_) => emit(const SplashComplete()),
    );
  }
}
