// Data-layer exceptions. Thrown by datasources and translated into
// Failures at the repository boundary.

class ServerException implements Exception {
  const ServerException([this.message = 'Server error', this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
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
