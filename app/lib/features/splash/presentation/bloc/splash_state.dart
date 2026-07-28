part of 'splash_bloc.dart';

sealed class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

class SplashInitial extends SplashState {
  const SplashInitial();
}

class SplashLoading extends SplashState {
  const SplashLoading();
}

class SplashComplete extends SplashState {
  const SplashComplete();
}

class SplashError extends SplashState {
  const SplashError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
