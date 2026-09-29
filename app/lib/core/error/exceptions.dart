// Data-layer exceptions. Thrown by datasources and translated into
// Failures at the repository boundary.

class ServerException implements Exception {
  const ServerException([this.message = 'Server error', this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// A structured error from the API's `{ error: { code, message, traceId } }`
/// envelope. [code] is the stable machine-readable code (e.g.
/// `VALIDATION_FAILED`, `RESOURCE_NOT_FOUND`); [traceId] correlates with the
/// `x-request-id` response header and belongs in logs, never in UI copy.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.traceId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? traceId;

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}

/// A premium wallpaper was requested without entitlement (HTTP 402).
class PaymentRequiredException implements Exception {
  const PaymentRequiredException([this.message = 'This wallpaper is premium']);
  final String message;
}

class NetworkTimeoutException implements Exception {
  const NetworkTimeoutException([this.message = 'Connection timed out']);
  final String message;
}

class NoInternetException implements Exception {
  const NoInternetException([this.message = 'No internet connection']);
  final String message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Unauthorized']);
  final String message;
}

class NotFoundException implements Exception {
  const NotFoundException([this.message = 'Not found']);
  final String message;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Cache error']);
  final String message;
}

class WallpaperApplyException implements Exception {
  const WallpaperApplyException([this.message = 'Failed to apply wallpaper']);
  final String message;
}
