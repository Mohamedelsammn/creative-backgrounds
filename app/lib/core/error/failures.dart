import 'package:equatable/equatable.dart';

/// Base type for all domain-level failures surfaced through
/// `Either<Failure, T>`. [message] is a safe, developer-facing default;
/// user-facing copy is resolved by `ErrorHandler.mapFailureToMessage`.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkTimeoutFailure extends Failure {
  const NetworkTimeoutFailure([super.message = 'The connection timed out.']);
}

class NoInternetFailure extends Failure {
  const NoInternetFailure([super.message = 'No internet connection.']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized request.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested item was not found.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to read local data.']);
}

class WallpaperApplyFailure extends Failure {
  const WallpaperApplyFailure([super.message = 'Failed to apply the wallpaper.']);
}

class DepthNotSupportedFailure extends Failure {
  const DepthNotSupportedFailure([
    super.message = 'Depth effect is not available for this wallpaper.',
  ]);
}

/// The user enabled the depth effect, but its cut-out foreground could not be
/// downloaded (or is missing). Distinct from [DepthNotSupportedFailure] -
/// that is a capability check made before the user can even turn depth on;
/// this is a failure of the apply itself, after they asked for it. The apply
/// must not silently degrade to a flat wallpaper here, or the user has no way
/// to know the effect they explicitly chose never actually applied.
class DepthForegroundMissingFailure extends Failure {
  const DepthForegroundMissingFailure([
    super.message =
        "Couldn't apply the depth effect - the cut-out image is missing. Try again.",
  ]);
}

/// A premium wallpaper was requested without entitlement (HTTP 402).
class PremiumRequiredFailure extends Failure {
  const PremiumRequiredFailure([
    super.message = 'This wallpaper requires premium.',
  ]);
}

/// A structured 4xx from the API (see `ApiException.code`). Distinct from
/// [ServerFailure] so retry-vs-report decisions can differ.
class ApiFailure extends Failure {
  const ApiFailure([super.message = 'The request could not be completed.']);
}

/// The wallpaper is a type this build cannot render or apply - either a
/// future content type the backend added, or one applied through a different
/// native path.
class UnsupportedWallpaperFailure extends Failure {
  const UnsupportedWallpaperFailure([
    super.message = 'This wallpaper type is not supported on your device yet.',
  ]);
}
