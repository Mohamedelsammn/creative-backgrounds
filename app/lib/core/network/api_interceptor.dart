import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// Adds auth, optional logging, and normalizes transport errors into typed
/// data-layer exceptions carried on [DioException.error].
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // The public feed needs no auth; only send a bearer token if one is
    // actually configured (the admin API is the only consumer that needs it).
    if (AppConfig.apiKey.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${AppConfig.apiKey}';
    }
    if (AppConfig.loggingEnabled) {
      developer.log(
        '→ ${options.method} ${options.uri}',
        name: 'API',
      );
      if (options.data != null) {
        developer.log('  body: ${options.data}', name: 'API');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (AppConfig.loggingEnabled) {
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.uri}',
        name: 'API',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (AppConfig.loggingEnabled) {
      developer.log(
        '✗ ${err.response?.statusCode ?? ''} ${err.requestOptions.uri} — ${err.type}',
        name: 'API',
        error: err.message,
      );
    }
    handler.next(err.copyWith(error: mapDioException(err)));
  }

  /// Translates a [DioException] into a typed data-layer exception.
  static Exception mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkTimeoutException();
      case DioExceptionType.connectionError:
        return const NoInternetException();
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        final envelope = _readErrorEnvelope(err.response?.data);
        if (status == 401 || status == 403) return const UnauthorizedException();
        if (status == 404) return const NotFoundException();
        if (status == 402) {
          return PaymentRequiredException(
            envelope?.message ?? 'This wallpaper is premium',
          );
        }
        // A structured envelope tells us far more than the status alone
        // (e.g. VALIDATION_FAILED on a query param we built wrong).
        if (envelope != null) {
          return ApiException(
            code: envelope.code,
            message: envelope.message,
            statusCode: status,
            traceId: envelope.traceId,
          );
        }
        if (status >= 500) return ServerException('Server error', status);
        return ServerException('Request failed', status);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // A socket/DNS failure commonly arrives as `unknown` with a
        // SocketException cause — treat as no-internet.
        if (err.error is Exception && err.message?.contains('SocketException') == true) {
          return const NoInternetException();
        }
        return const ServerException('Unexpected network error');
    }
  }

  /// Extracts the API's `{ error: { code, message, traceId } }` envelope.
  /// Returns null when the body is not that shape.
  static _ErrorEnvelope? _readErrorEnvelope(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;
    final code = error['code'];
    final message = error['message'];
    if (code is! String || message is! String) return null;
    return _ErrorEnvelope(
      code: code,
      message: message,
      traceId: error['traceId'] as String?,
    );
  }
}

class _ErrorEnvelope {
  const _ErrorEnvelope({
    required this.code,
    required this.message,
    this.traceId,
  });

  final String code;
  final String message;
  final String? traceId;
}
