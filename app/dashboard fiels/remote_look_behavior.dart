// Companion to remote_clock_config_mapper.dart: the parts of a wallpaper's look that are not the
// clock. What the app does when the wallpaper is applied, how the weather widget is drawn, and how
// an uploaded font gets onto the device.
//
// WRITTEN FROM THE CONTRACT, NOT COMPILED. The Flutter project is not in this repository, so the
// imports, the class names and the two packages this leans on (`http`, and a directory to cache
// into, from `path_provider`) are assumptions to adjust. The parsing and the loading rules are the
// part worth keeping. docs/MOBILE_APP_CONTRACT.md says what every field means.
//
// THE APP HAS NO EDITOR. Everything below is read from the wallpaper and performed. Every parser
// takes anything and returns something valid, because a malformed remote value should cost one
// field, not the whole look, and an older wallpaper that carries none of these reads as defaults.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// -------------------------------------------------------------------------------------------
// Behavior: `card['studio']['behavior']`
// -------------------------------------------------------------------------------------------

enum ApplyTarget { ask, lock, home, both }

enum ClockEntrance { none, fade, rise, scale }

class WallpaperBehavior {
  const WallpaperBehavior({
    this.applyTarget = ApplyTarget.ask,
    this.clockEntrance = ClockEntrance.none,
    this.clockEntranceMs = 600,
  });

  /// `ask` keeps the person's own choice of screen. The other three answer it, so the app applies
  /// straight away. Map them to the platform's own targets: on Android the lock, home and both
  /// flags of `WallpaperManager`, and on iOS the share sheet has no equivalent, so `ask` is the
  /// only behaviour there.
  final ApplyTarget applyTarget;

  final ClockEntrance clockEntrance;

  /// 100 to 3000. Skip the entrance entirely when the platform's reduced motion setting is on.
  final int clockEntranceMs;

  /// What a wallpaper with no behavior block does. Also the answer for anything unreadable.
  static const fallback = WallpaperBehavior();

  factory WallpaperBehavior.fromJson(Object? json) {
    if (json is! Map) return fallback;

    final target = _enumByName(ApplyTarget.values, json['applyTarget']) ?? ApplyTarget.ask;
    final entrance =
        _enumByName(ClockEntrance.values, json['clockEntrance']) ?? ClockEntrance.none;

    final rawMs = json['clockEntranceMs'];
    final ms = rawMs is num ? rawMs.round().clamp(100, 3000) : 600;

    return WallpaperBehavior(applyTarget: target, clockEntrance: entrance, clockEntranceMs: ms);
  }
}

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

// -------------------------------------------------------------------------------------------
// The weather widget: an entry of `card['studio']['widgets']` with `kind: 'weather'`
// -------------------------------------------------------------------------------------------

enum WeatherLayout { inline, stacked, compact }

enum WeatherIconStyle { none, filled, outline }

/// How the weather widget looks. The readings are the device's: resolve its own location, fetch
/// the current conditions, and draw them in this style. If the location permission is denied or
/// the request fails, draw nothing for this widget. Never a placeholder.
class WeatherWidgetSpec {
  const WeatherWidgetSpec({
    required this.fahrenheit,
    required this.layout,
    required this.iconStyle,
    required this.font,
    required this.weight,
    required this.showCondition,
    required this.showCity,
    required this.showHighLow,
  });

  final bool fahrenheit;
  final WeatherLayout layout;
  final WeatherIconStyle iconStyle;
  final String font;
  final int weight;
  final bool showCondition;
  final bool showCity;
  final bool showHighLow;

  /// `compact` is the temperature alone, so it ignores the three show flags.
  bool get showsDetails => layout != WeatherLayout.compact;

  factory WeatherWidgetSpec.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight'];

    return WeatherWidgetSpec(
      fahrenheit: json['unit'] == 'fahrenheit',
      layout: _enumByName(WeatherLayout.values, json['layout']) ?? WeatherLayout.inline,
      iconStyle:
          _enumByName(WeatherIconStyle.values, json['iconStyle']) ?? WeatherIconStyle.none,
      font: json['font'] is String && (json['font'] as String).isNotEmpty
          ? json['font'] as String
          : 'Inter',
      weight: rawWeight is num ? rawWeight.round().clamp(100, 900) : 400,
      showCondition: json['showCondition'] is bool ? json['showCondition'] as bool : true,
      showCity: json['showCity'] is bool ? json['showCity'] as bool : false,
      showHighLow: json['showHighLow'] is bool ? json['showHighLow'] as bool : false,
    );
  }
}

// -------------------------------------------------------------------------------------------
// Fonts: `GET /api/v1/public/config` -> `studio.fonts`
// -------------------------------------------------------------------------------------------

/// Downloads, caches and registers the fonts an administrator uploaded.
///
/// Each entry is `{ family, url, format, bytes, checksum }`. A null `url` is a font the app ships
/// itself, and nothing is loaded for it. Otherwise the file is fetched once and cached under its
/// `checksum`, which changes only when an administrator replaces the file, so a cached file with a
/// matching checksum is never fetched again.
///
/// **Never blocks applying a wallpaper.** A download that fails leaves that wallpaper on the
/// fallback face and is retried the next time this runs. Call it at launch, before drawing a look
/// that names one of these fonts, and again whenever the public config is refreshed.
class RemoteFontLoader {
  RemoteFontLoader({required this.cacheDirectory, http.Client? client})
      : _client = client ?? http.Client();

  /// Somewhere that survives a restart, e.g. a `fonts` folder under the app's support directory.
  final Directory cacheDirectory;
  final http.Client _client;

  /// The checksum each family was registered from, so an unchanged font is not loaded twice.
  final Map<String, String> _registered = {};

  Future<void> load(Object? fonts) async {
    if (fonts is! List) return;

    for (final entry in fonts) {
      if (entry is Map) await _loadOne(Map<String, dynamic>.from(entry));
    }
  }

  Future<void> _loadOne(Map<String, dynamic> font) async {
    final family = font['family'];
    final url = font['url'];
    final checksum = font['checksum'];

    // A bundled font has no url, and a file with no checksum cannot be cached safely.
    if (family is! String || url is! String || checksum is! String) return;
    if (_registered[family] == checksum) return;

    try {
      final format = font['format'] == 'otf' ? 'otf' : 'ttf';
      final cached = File('${cacheDirectory.path}/$checksum.$format');

      Uint8List bytes;
      if (await cached.exists()) {
        bytes = await cached.readAsBytes();
      } else {
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode != 200) return;

        bytes = response.bodyBytes;
        await cached.create(recursive: true);
        await cached.writeAsBytes(bytes, flush: true);
      }

      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();

      // Flutter keeps the first face registered under a family for the life of the process, so a
      // file an administrator replaced is drawn from the next launch. The checksum still changes,
      // so the new file is downloaded and cached now.
      _registered[family] = checksum;
    } catch (_) {
      // Fall back to the bundled or system face. The next run retries.
    }
  }
}
