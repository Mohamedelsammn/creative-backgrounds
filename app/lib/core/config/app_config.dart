import 'package:flutter/foundation.dart';
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

  /// Absolute URL of the remote update-policy document consumed by
  /// `UpdatePolicyRemoteDatasource` (Feature 1 - force update).
  ///
  /// Kept separate from [baseUrl] on purpose: the gate must stay operable
  /// even if the content API is moved, versioned, or temporarily down, and a
  /// static JSON document can be hosted somewhere far cheaper to keep up
  /// than the full API. Blank disables the remote fetch entirely, which
  /// resolves to [UpdatePolicy.failOpen] (no gate) rather than any default
  /// minimum - so an unset value can never lock users out.
  static String get updatePolicyUrl => _string('UPDATE_POLICY_URL');

  // Network
  static int get connectTimeoutMs => _int('TIMEOUT_CONNECT_MS', fallback: 10000);
  static int get receiveTimeoutMs => _int('TIMEOUT_RECEIVE_MS', fallback: 30000);

  // Features
  static bool get premiumEnabled => _bool('ENABLE_PREMIUM', fallback: true);
  static bool get depthWallpapersEnabled =>
      _bool('ENABLE_DEPTH_WALLPAPERS', fallback: true);
  static bool get liveClockEnabled => _bool('ENABLE_LIVE_CLOCK', fallback: true);

  // Development
  /// Whether request/response logging (`ApiInterceptor`) is active.
  ///
  /// Gated on `!kReleaseMode` the same way [useRealAdUnits] is gated on
  /// `kReleaseMode` - a `.env` value alone is not a safe production gate,
  /// since a local `.env` can be left with `LOGGING_ENABLED=true` (a normal
  /// development setting) and that exact file is what `pubspec.yaml` bundles
  /// verbatim into the release artifact. Without this, a forgotten `.env`
  /// flag ships verbose API logs (method/URL/request body/response status)
  /// to `adb logcat` on every user's device in a release build. Compile-time
  /// `kReleaseMode` cannot be left in the wrong state by a stale file the way
  /// an env flag can, so it - not `.env` - is the actual production gate;
  /// `.env`'s `LOGGING_ENABLED` still controls logging in debug/profile.
  static bool get loggingEnabled => !kReleaseMode && _bool('LOGGING_ENABLED');

  /// When true, remote datasources are backed by bundled fixtures instead of
  /// hitting [baseUrl]. Lets the full UI run before a live API key exists.
  static bool get mockApi => _bool('MOCK_API');

  // Ads
  /// Whether AdConstants should serve the real, revenue-generating ad unit
  /// IDs instead of Google's official test IDs.
  ///
  /// Driven by `kReleaseMode` (a compile-time constant baked in by
  /// `--release` vs `--debug`/`--profile`), never by a `.env` value: an env
  /// flag can be left in the wrong state by accident (forgotten toggle,
  /// stale `.env` copied between machines), which for ads specifically means
  /// either serving real ads during development (AdMob account risk from
  /// invalid/test traffic) or shipping test ads to real users (zero
  /// revenue). `FORCE_TEST_ADS=true` is a deliberate escape hatch to keep
  /// serving test ads even in a release build - e.g. testing a release
  /// candidate APK before the real Play Store submission.
  static bool get useRealAdUnits =>
      kReleaseMode && !_bool('FORCE_TEST_ADS');

  /// Structured `[ADS][FORMAT] ...` diagnostics. Always on in debug builds;
  /// in a release build only when `.env` sets `ADS_DEBUG_LOG=true` - a
  /// local, never-uploaded diagnostic build for reading real AdMob errors on
  /// a phone. The shipped `.env` must not set it.
  static bool get adsDiagnostics => kDebugMode || _bool('ADS_DEBUG_LOG');
}
