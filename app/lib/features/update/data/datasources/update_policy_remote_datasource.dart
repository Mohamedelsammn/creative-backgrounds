import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/update_policy.dart';

/// Fetches the remote update policy.
///
/// Returns null - never throws, and never returns a partially-trusted policy
/// - for every failure mode (offline, timeout, non-200, malformed body,
/// missing `android` object, unparseable build number). The caller turns a
/// null into [UpdatePolicy.failOpen], which is what keeps a config outage
/// from locking users out.
abstract class UpdatePolicyRemoteDatasource {
  Future<UpdatePolicy?> fetchPolicy();
}

class UpdatePolicyRemoteDatasourceImpl implements UpdatePolicyRemoteDatasource {
  UpdatePolicyRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  /// Deliberately short and independent of the app's general API timeouts:
  /// this call sits on the startup path, so it must fail fast rather than
  /// hold Splash for the 10s/30s connect/receive budget the content API uses.
  static const Duration _timeout = Duration(seconds: 5);

  @override
  Future<UpdatePolicy?> fetchPolicy() async {
    try {
      // Inside the try on purpose: dotenv throws NotInitializedError when
      // `.env` was never loaded, so reading config is itself a failure path
      // that must resolve to "no policy" (fail-open) rather than escaping
      // into the startup sequence.
      final url = AppConfig.updatePolicyUrl;
      if (url.isEmpty) return null;

      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          // A policy document is public config, not an authenticated
          // resource; any non-200 is treated as "no usable policy".
          validateStatus: (status) => status == 200,
        ),
      );
      return _parse(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Tolerant parser: anything unexpected yields null (fail-open) rather
  /// than a half-populated policy that might block users on a typo.
  ///
  /// Exposed for testing because this is untrusted input sitting on the
  /// startup path - its malformed-input behaviour is the part most worth
  /// pinning down directly, without a network round trip.
  @visibleForTesting
  static UpdatePolicy? parseBody(dynamic body) => _parse(body);

  static UpdatePolicy? _parse(dynamic body) {
    try {
      final root = body is Map ? body : null;
      if (root == null) return null;

      // Accept either a platform-scoped document ({"android": {...}}) or a
      // flat one, so the backend can serve either shape.
      final androidRaw = root['android'];
      final node = androidRaw is Map ? androidRaw : root;

      final minimum = _asInt(node['minimumSupportedBuild']);
      if (minimum == null) return null;

      return UpdatePolicy(
        minimumSupportedBuild: minimum,
        latestBuild: _asInt(node['latestBuild']),
        // Absent forceUpdate defaults to true: a policy that bothered to
        // publish a minimum build is asserting that minimum. The flag exists
        // to switch the gate OFF explicitly.
        forceUpdate: _asBool(node['forceUpdate']) ?? true,
        storeUrl: _asNonBlankString(node['storeUrl']),
        messages: _asMessages(node['updateMessage']),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  static String? _asNonBlankString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Map<String, String> _asMessages(dynamic value) {
    if (value is! Map) return const {};
    final out = <String, String>{};
    value.forEach((key, raw) {
      if (key is String && raw is String && raw.trim().isNotEmpty) {
        out[key] = raw;
      }
    });
    return out;
  }
}
