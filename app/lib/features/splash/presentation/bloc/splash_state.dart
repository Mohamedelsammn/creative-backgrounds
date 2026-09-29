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

/// Ads are being blocked (VPN, ad-blocking DNS filter, or several sessions
/// of every ad request failing) - the app is ad-funded and cannot proceed
/// past this point. See `AdIntegrityService`.
class SplashAdsBlocked extends SplashState {
  const SplashAdsBlocked();
}

/// The installed build is below the remotely-configured
/// `minimumSupportedBuild` (see `AppUpdateService`) - the
/// user must update before continuing. See `AppUpdateService`.
class SplashUpdateRequired extends SplashState {
  const SplashUpdateRequired();
}

class SplashError extends SplashState {
  const SplashError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
