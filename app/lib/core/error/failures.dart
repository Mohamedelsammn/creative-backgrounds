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
