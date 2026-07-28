import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessor over the values loaded from `.env` via [dotenv].
///
/// [dotenv] must be loaded (`await dotenv.load()`) before any getter here is
/// read — this happens in `main()` before `setupDI()`.
class AppConfig {
  const AppConfig._();

  static String _string(String key, {String fallback = ''}) =>
      dotenv.env[key] ?? fallback;

  static int _int(String key, {int fallback = 0}) =>
      int.tryParse(dotenv.env[key] ?? '') ?? fallback;

  static bool _bool(String key, {bool fallback = false}) {
    final raw = dotenv.env[key]?.toLowerCase().trim();
    if (raw == null || raw.isEmpty) return fallback;
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  // API
  static String get baseUrl => _string('BASE_URL');
  static String get apiKey => _string('API_KEY');
  static String get imageBaseUrl => _string('IMAGE_BASE_URL');

  // Network
  static int get connectTimeoutMs => _int('TIMEOUT_CONNECT_MS', fallback: 10000);
  static int get receiveTimeoutMs => _int('TIMEOUT_RECEIVE_MS', fallback: 30000);

  // Features
  static bool get premiumEnabled => _bool('ENABLE_PREMIUM', fallback: true);
  static bool get depthWallpapersEnabled =>
      _bool('ENABLE_DEPTH_WALLPAPERS', fallback: true);
  static bool get liveClockEnabled => _bool('ENABLE_LIVE_CLOCK', fallback: true);

  // Development
  static bool get debugMode => _bool('DEBUG_MODE');
  static bool get loggingEnabled => _bool('LOGGING_ENABLED');

  /// When true, remote datasources are backed by bundled fixtures instead of
  /// hitting [baseUrl]. Lets the full UI run before a live API key exists.
  static bool get mockApi => _bool('MOCK_API');
}
