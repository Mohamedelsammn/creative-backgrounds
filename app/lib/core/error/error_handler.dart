import 'exceptions.dart';
import 'failures.dart';

/// Maps a [Failure] to user-facing copy.
///
/// Kept English-only at this layer; screens that need localized text pass the
/// failure through `AppLocalizations` in Phase 18. The default strings here are
/// safe fallbacks used before localization resolves.
class ErrorHandler {
  const ErrorHandler._();

  /// Translates a data-layer exception (thrown by datasources) into a
  /// domain [Failure]. Called at the repository boundary.
  static Failure mapExceptionToFailure(Object error) {
    return switch (error) {
      NoInternetException() => const NoInternetFailure(),
      NetworkTimeoutException() => const NetworkTimeoutFailure(),
      UnauthorizedException() => const UnauthorizedFailure(),
      NotFoundException() => const NotFoundFailure(),
      PaymentRequiredException() => const PremiumRequiredFailure(),
      // A structured API error: 4xx is our request's fault, 5xx is theirs.
      ApiException(:final statusCode) =>
        (statusCode ?? 500) >= 500 ? const ServerFailure() : const ApiFailure(),
      ServerException() => const ServerFailure(),
      CacheException() => const CacheFailure(),
      WallpaperApplyException() => const WallpaperApplyFailure(),
      _ => const UnknownFailure(),
    };
  }

  static String mapFailureToMessage(Failure failure) {
    switch (failure) {
      case NoInternetFailure():
        return 'No internet connection. Please check your network and try again.';
      case NetworkTimeoutFailure():
        return 'The connection timed out. Please try again.';
      case UnauthorizedFailure():
        return 'Your session could not be verified. Please try again.';
      case NotFoundFailure():
        return 'We couldn\'t find what you were looking for.';
      case ServerFailure():
        return 'Our servers are having a moment. Please try again shortly.';
      case CacheFailure():
        return 'Failed to load saved data.';
      case WallpaperApplyFailure():
        return 'We couldn\'t set your wallpaper. Please try again.';
      case DepthNotSupportedFailure():
        return 'Depth effect isn\'t available for this wallpaper.';
      // Carries its own explanation - distinct from DepthNotSupportedFailure,
      // this is an apply-time failure to fetch the foreground, not a
      // capability check.
      case DepthForegroundMissingFailure():
        return failure.message;
      case PremiumRequiredFailure():
        return 'This wallpaper is available to premium members.';
      case ApiFailure():
        return 'We couldn\'t load that right now. Please try again.';
      // Carries its own explanation of which type is unsupported and why.
      case UnsupportedWallpaperFailure():
        return failure.message;
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
