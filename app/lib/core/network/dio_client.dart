import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_interceptor.dart';

/// Thin singleton wrapper around a configured [Dio] instance.
///
/// Registered once in GetIt; all remote datasources depend on `DioClient.dio`.
class DioClient {
  DioClient() : dio = Dio(_baseOptions()) {
    dio.interceptors.add(ApiInterceptor());
  }

  final Dio dio;

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: Duration(milliseconds: AppConfig.connectTimeoutMs),
        receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      );
}
