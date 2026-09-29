// Drop-in replacement for lib/features/clock/data/models/remote_clock_config_mapper.dart
//
// WRITTEN FROM THE SPEC, NOT COMPILED. The Flutter project is not in this repository, so this
// was written against DEPTH_WALLPAPER_FEATURE_SPEC.md and DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md
// rather than against the real source. Expect to fix the import path, the class/method name and
// the ClockConfigEntity constructor argument list to match what you actually have. The parsing
// and clamping logic is the part worth keeping.
//
// WHY: the current mapper reads only enabled/style/position/custom coordinates/font/weight/
// scale/rotation/color/opacity/depth/shadow/date/schemaVersion (spec 15.1). Everything the
// dashboard can now author beyond that - timeLayout, colorMode and the split colours, stretchY,
// dateScale, strokeWidth, sizePx, horizontalScale, glow, stroke, seconds, 24 hour - is dropped
// on the floor (spec 26, item 8). A wallpaper authored as a stacked two-colour Poster clock
// renders as a plain inline Inter clock on the device.
//
// The Android side already renders these fields (spec 20), because the local flat JSON carries
// them and ClockConfig.fromJson reads the flat fields it declares. So this file is the gap.
//
// SHAPE IT ACCEPTS: both the nested shadow/date objects the backend sends today (spec 5) and the
// flat spellings from the recommended contract (spec 6). Flat wins when both are present, so a
// backend can migrate one field at a time. Unknown keys are ignored; absent keys keep the
// built-in default, so an older backend payload maps exactly as it does now.
//
// WHERE THE CLOCK JSON IS (2026-09-19). Every feed, related and search card now carries the look
// without being asked, the same as the detail. Feed the right object to fromJson per type:
//
//   DEPTH            -> card['clockConfig']     draw it between card['background'] and
//                                               card['foreground']; card['studio']['clock'] is null
//   STANDARD, VIDEO  -> card['studio']['clock'] card['clockConfig'] is null
//
// Either can be null: no clock saved, or (for studio) a reviewer pulled the look back. For every
// type, card['studio'] also carries 'scene' (the grade), 'dateWidget' and 'widgets'. A saved look
// is live the moment it is saved, so the app never has to wait for an approval to show an edit.
// studio.clock also carries hourFormat ('12' | '24' | 'auto'); prefer it over is24Hour when set.
//
// ADDED 2026-09-19, all optional and defaulting to what the app drew without them: colorMode
// 'gradient' with gradientFrom/gradientTo/gradientAngleDeg, hoursFont and minutesFont, strokeColor
// and strokeOrder, fillOpacity, fadeAmount and fadeDirection, and blur. The new ClockConfigEntity
// members and the two enums they need (ClockStrokeOrder, ClockFadeDirection) have to be added to
// the entity; docs/MOBILE_APP_CONTRACT.md section 2 says what each does. The behavior block, the
// weather widget and font loading are in remote_look_behavior.dart.
import '../../domain/entities/clock_config_entity.dart';

class RemoteClockConfigMapper {
  const RemoteClockConfigMapper._();

  /// Keep whatever name and signature the existing mapper exposes; only the body changed.
  static ClockConfigEntity fromJson(Map<String, dynamic> json) {
    final rawStyle = _string(json['style']);
    final rawFont = _string(json['font']);

    // Nested (current backend) and flat (recommended contract) spellings of the same two groups.
    final shadow = _map(json['shadow']);
    final date = _map(json['date']);

    final customX = _doubleOrNull(json['customX'], min: 0, max: 1);
    final customY = _doubleOrNull(json['customY'], min: 0, max: 1);
    final hasExactPosition = customX != null && customY != null;

    // Spec 13.2: the legacy path derives the size from `scale` and clamps it harder than the
    // editor's own range. An explicit `sizePx` is the authored value and wins outright.
    final scale = _double(json['scale'], 1.0, min: 0.5, max: 3);
    final sizePx = json.containsKey('sizePx')
        ? _double(json['sizePx'], 65.0, min: 24, max: 320)
        : _clamp(76.0 * scale, 24, 120);

    // Spec 7.2: both renderers use the raw `weight` while remote authorship markers are set, so
    // a `fontWeightPreset` with no `weight` beside it would be silently ignored. Deriving the
    // weight from the preset is what makes the preset actually render.
    final weightPreset = _weightPreset(json['fontWeightPreset']);
    final weight = json.containsKey('weight')
        ? _int(json['weight'], 400, min: 100, max: 900)
        : (weightPreset != null ? _weightValue(weightPreset) : 400);

    return ClockConfigEntity(
      enabled: _bool(json['enabled'], true),

      // Spec 15.1: an unknown style falls back to modern visually while the raw identifier is
      // preserved, so a newer backend value survives a round trip through an older build.
      style: _style(rawStyle),
      remoteStyle: rawStyle,
      font: _font(rawFont),
      remoteFont: rawFont,

      // Spec 15.1: `position: custom` resolves an anchor from customY but keeps the exact
      // coordinates, which are what actually win when both are non null.
      position: hasExactPosition
          ? _anchorFromY(customY)
          : _position(_string(json['position'])),
      customX: customX,
      customY: customY,

      weight: weight,
      fontWeightPreset: weightPreset ?? ClockWeight.regular,
      scale: scale,
      sizePx: sizePx,
      horizontalScale: _double(json['horizontalScale'], 1.0, min: 0.55, max: 1.5),
      stretchY: _double(json['stretchY'], 1.0, min: 1.0, max: 3.0),
      rotation: _double(json['rotation'], 0.0, min: -180, max: 180),
      opacity: _double(json['opacity'], 1.0, min: 0, max: 1),

      color: _color(json['color']) ?? 0xFFFFFFFF,
      colorMode: _colorMode(json['colorMode']),
      hoursColor: _color(json['hoursColor']),
      minutesColor: _color(json['minutesColor']),
      colonColor: _colonColor(json['colonColor']),
      colonColorCustom: _color(json['colonColorCustom']),
      gradientFrom: _color(json['gradientFrom']),
      gradientTo: _color(json['gradientTo']),
      gradientAngleDeg: _double(json['gradientAngleDeg'], 180.0, min: 0, max: 360),
      fillOpacity: _double(json['fillOpacity'], 1.0, min: 0, max: 1),

      // A different face for each half of the time. Null means the clock's own `font`.
      hoursFont: _string(json['hoursFont']),
      minutesFont: _string(json['minutesFont']),

      timeLayout: _timeLayout(json['timeLayout']),
      showColon: _bool(json['showColon'], true),
      lineSpacing: _double(json['lineSpacing'], 1.0, min: 0.5, max: 2.0),
      minuteOffsetX: _double(json['minuteOffsetX'], 0.0, min: -1, max: 1),

      is24Hour: _bool(json['is24Hour'], false),
      showSeconds: _bool(json['showSeconds'], false),
      // Added 2026-09-20. A 12 hour clock's AM or PM mark: small, after the minutes. Off removes it.
      // Ignored by a 24 hour clock. Defaults to on, which is what a clock drew before it existed.
      showAmPm: _bool(json['showAmPm'], true),

      showDate: _bool(json['showDate'] ?? date?['enabled'], true),
      datePosition: _datePosition(json['datePosition'] ?? date?['position']),
      dateColor: _color(json['dateColor'] ?? date?['color']),
      dateScale: _double(json['dateScale'], 1.0, min: 0.5, max: 2.0),

      showShadow: _bool(json['showShadow'] ?? shadow?['enabled'], true),
      shadowStrength:
          _double(json['shadowStrength'] ?? shadow?['strength'], 0.5, min: 0, max: 1),
      showGlow: _bool(json['showGlow'], false),
      showStroke: _bool(json['showStroke'], false),
      strokeWidth: _double(json['strokeWidth'], 2.0, min: 0.5, max: 20),
      strokeColor: _color(json['strokeColor']) ?? 0xFF000000,
      strokeOrder: _strokeOrder(json['strokeOrder']),

      // Atmospheric depth, applied to the time only. The date the clock carries stays crisp.
      fadeAmount: _double(json['fadeAmount'], 0.0, min: 0, max: 1),
      fadeDirection: _fadeDirection(json['fadeDirection']),
      blur: _double(json['blur'], 0.0, min: 0, max: 20),

      // Spec 14.1: mapped and persisted, but neither renderer uses it.
      depth: _double(json['depth'], 0.45, min: 0, max: 1),
      schemaVersion: _int(json['schemaVersion'], 1, min: 1, max: 1 << 30),
    );
  }

  // ---------------------------------------------------------------------------------------
  // Enums. Explicit maps rather than `values.byName`, because the remote vocabulary is not the
  // local one: the compatibility inputs below have no matching enum name at all.
  // ---------------------------------------------------------------------------------------

  static const _styles = <String, ClockStyle>{
    'modern': ClockStyle.modern,
    'minimal': ClockStyle.minimal,
    'elegant': ClockStyle.elegant,
    'digital': ClockStyle.digital,
    'condensed': ClockStyle.condensed,
    'poster': ClockStyle.poster,
    'outline': ClockStyle.outline,
    'split': ClockStyle.split,
    'futuristic': ClockStyle.futuristic,
    'editorial': ClockStyle.editorial,
    'monument': ClockStyle.monument,
    'stencil': ClockStyle.stencil,
    'soft': ClockStyle.soft,
    // Spec 2: compatibility inputs. Not interchangeable with the canonical ids above.
    'thin': ClockStyle.minimal,
    'classic': ClockStyle.elegant,
    'solid': ClockStyle.modern,
    'bold': ClockStyle.modern,
    'rounded': ClockStyle.modern,
    'outlined': ClockStyle.modern,
  };

  static ClockStyle _style(String? raw) =>
      _styles[raw?.toLowerCase().trim()] ?? ClockStyle.modern;

  /// Spec 7.1: the canonical ids first, then the substring rules the current mapper uses for
  /// names that came from somewhere else ("PlayfairDisplay", "JetBrains Mono", "Courier New").
  static ClockFont _font(String? raw) {
    final value = raw?.toLowerCase().trim();
    if (value == null || value.isEmpty) return ClockFont.inter;

    const canonical = <String, ClockFont>{
      'inter': ClockFont.inter,
      'serif': ClockFont.serif,
      'mono': ClockFont.mono,
      'oswald': ClockFont.oswald,
      'archivoblack': ClockFont.archivoBlack,
      'anton': ClockFont.anton,
    };

    final exact = canonical[value.replaceAll(' ', '')];
    if (exact != null) return exact;

    const serifish = ['playfair', 'serif', 'georgia', 'times', 'merriweather'];
    const monoish = ['mono', 'jetbrains', 'courier', 'code'];

    if (serifish.any(value.contains)) return ClockFont.serif;
    if (monoish.any(value.contains)) return ClockFont.mono;
    if (value.contains('oswald')) return ClockFont.oswald;
    if (value.contains('archivo')) return ClockFont.archivoBlack;
    if (value.contains('anton')) return ClockFont.anton;

    return ClockFont.inter;
  }

  static ClockPosition _position(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'center':
        return ClockPosition.center;
      case 'bottom':
        return ClockPosition.bottom;
      case 'top':
      case 'custom': // Resolved by the caller from customY when both coordinates are present.
      default:
        return ClockPosition.top;
    }
  }

  /// Spec 11: the anchor a `custom` position reads as, using the same thresholds the anchors
  /// themselves sit at (top 0.16, bottom 0.74). Only a fallback; the coordinates still win.
  static ClockPosition _anchorFromY(double? y) {
    if (y == null) return ClockPosition.top;
    if (y < 0.4) return ClockPosition.top;
    if (y > 0.65) return ClockPosition.bottom;
    return ClockPosition.center;
  }

  static ClockTimeLayout _timeLayout(Object? raw) {
    switch (_string(raw)?.trim()) {
      case 'stacked':
        return ClockTimeLayout.stacked;
      case 'stackedCompact':
        return ClockTimeLayout.stackedCompact;
      case 'offsetStack':
        return ClockTimeLayout.offsetStack;
      case 'verticalPoster':
        return ClockTimeLayout.verticalPoster;
      default:
        return ClockTimeLayout.inline;
    }
  }

  /// `auto` is read as `single` on purpose: it asks the device to derive a colour from the artwork
  /// (docs/CLOCK_AUTO_COLOR.md), and `color` is the fallback a build without that reads instead.
  static ClockColorMode _colorMode(Object? raw) {
    switch (_string(raw)?.toLowerCase().trim()) {
      case 'split':
        return ClockColorMode.split;
      case 'gradient':
        return ClockColorMode.gradient;
      default:
        return ClockColorMode.single;
    }
  }

  /// `behind` paints the stroke first so only its outer half shows; `front` paints it over the fill.
  static ClockStrokeOrder _strokeOrder(Object? raw) =>
      _string(raw)?.toLowerCase().trim() == 'front'
          ? ClockStrokeOrder.front
          : ClockStrokeOrder.behind;

  static ClockFadeDirection _fadeDirection(Object? raw) {
    switch (_string(raw)?.toLowerCase().trim()) {
      case 'top':
        return ClockFadeDirection.top;
      case 'both':
        return ClockFadeDirection.both;
      default:
        return ClockFadeDirection.bottom;
    }
  }

  static ClockColonColor _colonColor(Object? raw) {
    switch (_string(raw)?.toLowerCase().trim()) {
      case 'minutes':
        return ClockColonColor.minutes;
      case 'custom':
        return ClockColonColor.custom;
      default:
        return ClockColonColor.hours;
    }
  }

  static ClockDatePosition _datePosition(Object? raw) =>
      _string(raw)?.toLowerCase().trim() == 'above'
          ? ClockDatePosition.above
          : ClockDatePosition.below;

  static const _weights = <String, ClockWeight>{
    'extraLight': ClockWeight.extraLight,
    'light': ClockWeight.light,
    'regular': ClockWeight.regular,
    'medium': ClockWeight.medium,
    'semiBold': ClockWeight.semiBold,
    'bold': ClockWeight.bold,
    'extraBold': ClockWeight.extraBold,
    'black': ClockWeight.black,
  };

  static ClockWeight? _weightPreset(Object? raw) => _weights[_string(raw)?.trim()];

  static int _weightValue(ClockWeight preset) {
    switch (preset) {
      case ClockWeight.extraLight:
        return 200;
      case ClockWeight.light:
        return 300;
      case ClockWeight.regular:
        return 400;
      case ClockWeight.medium:
        return 500;
      case ClockWeight.semiBold:
        return 600;
      case ClockWeight.bold:
        return 700;
      case ClockWeight.extraBold:
        return 800;
      case ClockWeight.black:
        return 900;
    }
  }

  // ---------------------------------------------------------------------------------------
  // Scalars. Every one of these takes anything and returns something in range, because a
  // malformed remote value should cost one field, not the whole clock (spec 21).
  // ---------------------------------------------------------------------------------------

  static String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

  static double _clamp(double value, double min, double max) =>
      value.isNaN ? min : (value < min ? min : (value > max ? max : value));

  static double _double(Object? value, double fallback, {required num min, required num max}) {
    final parsed = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    return parsed == null ? fallback : _clamp(parsed, min.toDouble(), max.toDouble());
  }

  static double? _doubleOrNull(Object? value, {required num min, required num max}) {
    if (value == null) return null;
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed == null ? null : _clamp(parsed, min.toDouble(), max.toDouble());
  }

  static int _int(Object? value, int fallback, {required int min, required int max}) {
    final parsed = value is num ? value.round() : int.tryParse('${value ?? ''}');
    if (parsed == null) return fallback;
    return parsed < min ? min : (parsed > max ? max : parsed);
  }

  /// CSS `#RRGGBB` or `#RRGGBBAA` to an ARGB int (spec 8.3).
  ///
  /// The byte order is the trap: CSS puts alpha last and Flutter's int puts it first, so
  /// `#FFFFFF80` is a half transparent white and `0x80FFFFFF` is the same colour as an int.
  /// Reading it positionally would produce an opaque grey instead.
  static int? _color(Object? value) {
    if (value is int) return value;

    final raw = _string(value)?.replaceFirst('#', '').trim();
    if (raw == null) return null;

    if (raw.length == 6) {
      final rgb = int.tryParse(raw, radix: 16);
      return rgb == null ? null : 0xFF000000 | rgb;
    }

    if (raw.length == 8) {
      final rgba = int.tryParse(raw, radix: 16);
      if (rgba == null) return null;
      final alpha = rgba & 0xFF;
      final rgb = rgba >> 8;
      return (alpha << 24) | rgb;
    }

    return null;
  }
}
