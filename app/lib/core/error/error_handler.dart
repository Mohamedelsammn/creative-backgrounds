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
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
