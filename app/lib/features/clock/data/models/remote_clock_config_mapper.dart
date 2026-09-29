import '../../../../core/utils/color_utils.dart';
import '../../domain/entities/clock_config_entity.dart';

/// Translates a backend-authored clock object into a [ClockConfigEntity].
///
/// The backend authors the clock in one of two containers (see
/// `docs/DESIGN_RENDERING_CONTRACT.md` §1.2):
///
///  * `studio.clock` - the current generation, 47 fields, no `schemaVersion`
///  * `clockConfig`  - the legacy generation, 46 fields, `schemaVersion: 1`
///
/// They share 45 fields with identical names and value shapes; `studio.clock`
/// adds `hourFormat`/`separatorBlink`, the legacy one adds `schemaVersion`.
/// Because the shapes agree, ONE parser reads both - the caller decides which
/// container to hand over (see `WallpaperModel.toEntity`), this class does not
/// need to know which generation it is looking at.
///
/// The two vocabularies still do not line up one-to-one, so this remains the
/// single place that reconciles them - nothing else in the app should know how
/// the backend spells a clock:
///
///  * backend style ids -> [ClockStyle], raw id kept in `remoteStyle`
///  * free-form `font` name -> bundled [ClockFont], raw kept in `remoteFont`
///  * `position: custom` + x/y -> nearest anchor, exact `customX/Y` preserved
///  * `shadow: {enabled, strength}` -> `showShadow` + `shadowStrength`
///  * `date: {enabled, position, color}` -> `showDate` + `datePosition` + `dateColor`
///  * `color: "#RRGGBBAA"` (CSS byte order) -> ARGB int
///
/// Every field is read defensively: a wrong type, an out-of-range number or an
/// unrecognised enum falls back to the documented default instead of throwing,
/// because one bad config must not take down the wallpaper it belongs to. An
/// unknown *field* is ignored outright, so a newer backend cannot break an
/// older build.
class RemoteClockConfigMapper {
  const RemoteClockConfigMapper._();

  /// Lower bound for a resolved font size. A clock below this is unreadable at
  /// any density, so it is treated as bad data rather than intent.
  static const double minSizePx = 24;

  /// Upper bound for a resolved font size.
  ///
  /// This is deliberately far above the legacy 120 ceiling. That 120 was an
  /// artifact of the old derived-size formula (`76 * scale`, scale <= 3.0) and
  /// was never a renderer limit: neither [ClockConfigEntity], nor
  /// `ClockConfigModel`, nor `ClockConfig.kt`, nor `ClockPainter`, nor
  /// `ClockRenderer.kt` imposes any ceiling - both renderers simply multiply
  /// `sizePx` by the display density. Clamping authored sizes to 120 silently
  /// shrank every large authored clock (a 208px design rendered at 76px).
  ///
  /// A bound is still kept so a corrupt value cannot allocate an absurd text
  /// layout. 320 is the dashboard's own documented maximum for this field
  /// (`docs/DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md` §3: "`sizePx` | 24 | 320 |
  /// 65 | Flutter logical pixels"), so it cannot be reached by legitimate
  /// authoring, while `ClockBounds` keeps an oversized-but-legitimate block
  /// on-canvas by its own size-aware math.
  static const double maxSizePx = 320;

  /// Parses a backend clock object. Returns null when [json] is absent or is
  /// not a map - callers read that as "this wallpaper has no authored clock".
  static ClockConfigEntity? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);

    final scale = _double(map['scale'], 1.0, min: 0.5, max: 3.0);
    final rawStyle = _string(map['style']);
    final rawFont = _string(map['font']);
    final shadow = map['shadow'];
    final date = map['date'];

    final customX = _nullableDouble(map['customX'], min: 0, max: 1);
    final customY = _nullableDouble(map['customY'], min: 0, max: 1);

    return ClockConfigEntity(
      enabled: _bool(map['enabled'], true),
      style: _styleFrom(rawStyle),
      remoteStyle: rawStyle,
      position: _positionFrom(map['position'], customY),
      customX: customX,
      customY: customY,
      font: _fontFrom(rawFont),
      remoteFont: rawFont,
      weight: _int(map['weight'], 400, min: 100, max: 900),
      scale: scale,
      // FLUTTER_RENDERING_GUIDE §3.1: size = W * 0.14 * scale * (sizePx / 65).
      // `scale` and `sizePx` are independent factors; an absent `sizePx`
      // is 65, never derived from `scale` (that would count it twice).
      sizePx: _double(map['sizePx'], 65, min: minSizePx, max: maxSizePx),
      rotation: _double(map['rotation'], 0, min: -180, max: 180),
      color: _color(map['color']) ?? 0xFFFFFFFF,
      opacity: _double(map['opacity'], 1.0, min: 0, max: 1),
      depth: _double(map['depth'], 0.45, min: 0, max: 1),
      // `showStroke` is authored directly by the current schema. The legacy
      // `outlined` style id implied it before that field existed, so it is
      // still honored as a fallback for configs that predate `showStroke`.
      showStroke: _bool(
        map['showStroke'],
        rawStyle?.toLowerCase() == 'outlined',
      ),
      showGlow: _bool(map['showGlow'], false),
      showSeconds: _bool(map['showSeconds'], false),
      // Contract default: on. A 24 hour clock ignores it.
      showAmPm: _bool(map['showAmPm'], true),
      // Authored by the dashboard's own editor - DEPTH_WALLPAPER_DASHBOARD
      // _CONTRACT.md 7 lists "12/24 hour, seconds | switches" among the
      // editor controls - so the authored design is authoritative here, the
      // same rule `showSeconds` already followed.
      is24Hour: _bool(map['is24Hour'], false),
      strokeWidth: _double(map['strokeWidth'], 2.0, min: 0.5, max: 20),
      // An absent sub-object means the author did not ask for the feature, so
      // it defaults OFF. (The previous `true` default drew a shadow and a date
      // on wallpapers that never authored either.)
      showShadow: shadow is Map ? _bool(shadow['enabled'], false) : false,
      shadowStrength: shadow is Map
          ? _double(shadow['strength'], 0.5, min: 0, max: 1)
          : 0.5,
      showDate: date is Map ? _bool(date['enabled'], false) : false,
      datePosition: date is Map
          ? _datePositionFrom(date['position'])
          : ClockDatePosition.below,
      dateColor: date is Map ? _color(date['color']) : null,
      dateScale: _double(map['dateScale'], 1.0, min: 0.5, max: 2.0),
      // --- typography -----------------------------------------------------
      fontWeightPreset: _weightPresetFrom(map['fontWeightPreset']),
      horizontalScale: _double(
        map['horizontalScale'],
        1.0,
        min: 0.55,
        max: 1.5,
      ),
      stretchY: _double(map['stretchY'], 1.0, min: 1.0, max: 3.0),
      // --- layout ---------------------------------------------------------
      timeLayout: _timeLayoutFrom(map['timeLayout']),
      showColon: _bool(map['showColon'], true),
      lineSpacing: _double(map['lineSpacing'], 1.0, min: 0.5, max: 2.0),
      minuteOffsetX: _double(map['minuteOffsetX'], 0.0, min: -1.0, max: 1.0),
      // --- split colour ---------------------------------------------------
      colorMode: _colorModeFrom(map['colorMode']),
      hoursColor: _color(map['hoursColor']),
      minutesColor: _color(map['minutesColor']),
      colonColor: _colonColorFrom(map['colonColor']),
      colonColorCustom: _color(map['colonColorCustom']),
      gradientFrom: _color(map['gradientFrom']),
      gradientTo: _color(map['gradientTo']),
      gradientAngleDeg: _double(map['gradientAngleDeg'], 180, min: 0, max: 360),
      fillOpacity: _double(map['fillOpacity'], 1.0, min: 0, max: 1),
      hoursFont: _nonEmpty(map['hoursFont']),
      minutesFont: _nonEmpty(map['minutesFont']),
      strokeColor: _color(map['strokeColor']) ?? 0xFF000000,
      strokeOrder: _string(map['strokeOrder'])?.trim() == 'front'
          ? ClockStrokeOrder.front
          : ClockStrokeOrder.behind,
      fadeAmount: _double(map['fadeAmount'], 0, min: 0, max: 1),
      fadeDirection: switch (_string(map['fadeDirection'])?.trim()) {
        'top' => ClockFadeDirection.top,
        'both' => ClockFadeDirection.both,
        _ => ClockFadeDirection.bottom,
      },
      blur: _double(map['blur'], 0, min: 0, max: 20),
      hourFormat: switch (_string(map['hourFormat'])?.trim()) {
        '12' => ClockHourFormat.h12,
        '24' => ClockHourFormat.h24,
        'auto' => ClockHourFormat.auto,
        _ => null,
      },
      // `studio.clock` carries no `schemaVersion`; absent means generation 1.
      schemaVersion: _int(map['schemaVersion'], 1, min: 1, max: 1 << 30),
    );
  }

  /// Serializes back to the backend shape. Used when persisting the remote
  /// default alongside the user's overrides, so a round-trip never silently
  /// drops a field the content team authored.
  static Map<String, dynamic> toJson(ClockConfigEntity e) => {
    'enabled': e.enabled,
    'style': e.remoteStyle ?? _wireStyleFor(e.style),
    'position': e.hasCustomPosition ? 'custom' : e.position.name,
    'customX': e.customX,
    'customY': e.customY,
    'font': e.remoteFont ?? _wireFontFor(e.font),
    'weight': e.weight,
    'scale': e.scale,
    'sizePx': e.sizePx,
    'rotation': e.rotation,
    'color': argbToCssHex(e.color),
    'opacity': e.opacity,
    'depth': e.depth,
    'showStroke': e.showStroke,
    'showGlow': e.showGlow,
    'showSeconds': e.showSeconds,
    'showAmPm': e.showAmPm,
    'is24Hour': e.is24Hour,
    'strokeWidth': e.strokeWidth,
    'shadow': {'enabled': e.showShadow, 'strength': e.shadowStrength},
    'date': {
      'enabled': e.showDate,
      'position': e.datePosition.name,
      'color': argbToCssHex(e.dateColor ?? e.color),
    },
    'dateScale': e.dateScale,
    'fontWeightPreset': e.fontWeightPreset.name,
    'horizontalScale': e.horizontalScale,
    'stretchY': e.stretchY,
    'timeLayout': e.timeLayout.name,
    'showColon': e.showColon,
    'lineSpacing': e.lineSpacing,
    'minuteOffsetX': e.minuteOffsetX,
    'colorMode': e.colorMode.name,
    'hoursColor': e.hoursColor == null ? null : argbToCssHex(e.hoursColor!),
    'minutesColor': e.minutesColor == null
        ? null
        : argbToCssHex(e.minutesColor!),
    'colonColor': e.colonColor.name,
    'colonColorCustom': e.colonColorCustom == null
        ? null
        : argbToCssHex(e.colonColorCustom!),
    'gradientFrom': e.gradientFrom == null ? null : argbToCssHex(e.gradientFrom!),
    'gradientTo': e.gradientTo == null ? null : argbToCssHex(e.gradientTo!),
    'gradientAngleDeg': e.gradientAngleDeg,
    'fillOpacity': e.fillOpacity,
    'hoursFont': e.hoursFont,
    'minutesFont': e.minutesFont,
    'strokeColor': argbToCssHex(e.strokeColor),
    'strokeOrder': e.strokeOrder.name,
    'fadeAmount': e.fadeAmount,
    'fadeDirection': e.fadeDirection.name,
    'blur': e.blur,
    'hourFormat': switch (e.hourFormat) {
      ClockHourFormat.h12 => '12',
      ClockHourFormat.h24 => '24',
      ClockHourFormat.auto => 'auto',
      null => null,
    },
    'schemaVersion': e.schemaVersion,
  };

  // --- enum bridges ------------------------------------------------------

  /// Maps a backend style id onto a [ClockStyle]. The raw id stays in
  /// `remoteStyle`.
  ///
  /// Every [ClockStyle] the renderers implement is reachable by its own name -
  /// the dashboard now authors ids like `monument` that map 1:1. The legacy
  /// aliases below (`thin`, `classic`, `solid`, `bold`, `rounded`, `outlined`)
  /// are kept so older wallpapers keep resolving exactly as before.
  static ClockStyle _styleFrom(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        // 1:1 with the renderers' own vocabulary.
        'modern' => ClockStyle.modern,
        'minimal' => ClockStyle.minimal,
        'elegant' => ClockStyle.elegant,
        'digital' => ClockStyle.digital,
        'condensed' => ClockStyle.condensed,
        'poster' => ClockStyle.poster,
        'outline' => ClockStyle.outline,
        'split' => ClockStyle.split,
        'futuristic' => ClockStyle.futuristic,
        'editorial' => ClockStyle.editorial,
        'monument' => ClockStyle.monument,
        'stencil' => ClockStyle.stencil,
        'soft' => ClockStyle.soft,
        // Legacy aliases, preserved for older authored wallpapers.
        'thin' => ClockStyle.minimal,
        'classic' => ClockStyle.elegant,
        'solid' || 'bold' || 'rounded' || 'outlined' => ClockStyle.modern,
        _ => ClockStyle.modern,
      };

  static String _wireStyleFor(ClockStyle style) => switch (style) {
    ClockStyle.modern => 'modern',
    ClockStyle.minimal => 'minimal',
    ClockStyle.elegant => 'elegant',
    ClockStyle.digital => 'digital',
    ClockStyle.condensed => 'condensed',
    ClockStyle.poster => 'poster',
    ClockStyle.outline => 'outline',
    ClockStyle.split => 'split',
    ClockStyle.futuristic => 'futuristic',
    ClockStyle.editorial => 'editorial',
    ClockStyle.monument => 'monument',
    ClockStyle.stencil => 'stencil',
    ClockStyle.soft => 'soft',
  };

  /// Maps a backend font family onto a bundled one.
  ///
  /// The bundled display faces (Oswald, Archivo Black, Anton) are matched by
  /// name first - the dashboard authors them directly, and they were
  /// previously unreachable, so an authored `Oswald` silently rendered as
  /// Inter. Serif- and mono-looking families are then matched by keyword;
  /// anything else falls back to Inter with the original name preserved in
  /// `remoteFont`.
  static ClockFont _fontFrom(String? raw) {
    final name = raw?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (name == null || name.isEmpty) return ClockFont.inter;
    if (name.contains('oswald')) return ClockFont.oswald;
    if (name.contains('archivoblack')) return ClockFont.archivoBlack;
    if (name.contains('anton')) return ClockFont.anton;
    const serif = ['playfair', 'serif', 'georgia', 'times', 'merriweather'];
    const mono = ['mono', 'jetbrains', 'courier', 'code'];
    if (serif.any(name.contains)) return ClockFont.serif;
    if (mono.any(name.contains)) return ClockFont.mono;
    return ClockFont.inter;
  }

  static String _wireFontFor(ClockFont font) => switch (font) {
    ClockFont.inter => 'Inter',
    ClockFont.serif => 'PlayfairDisplay',
    ClockFont.mono => 'JetBrainsMono',
    ClockFont.oswald => 'Oswald',
    ClockFont.archivoBlack => 'ArchivoBlack',
    ClockFont.anton => 'Anton',
  };

  /// The backend can author an exact position (`custom` plus x/y). The app UI
  /// offers three anchors, so `custom` resolves to the nearest one by its
  /// vertical coordinate; [ClockConfigEntity.customX] and `customY` keep the
  /// exact values, and both renderers prefer them whenever they are present.
  static ClockPosition _positionFrom(Object? raw, double? customY) {
    switch (raw) {
      case 'top':
        return ClockPosition.top;
      case 'bottom':
        return ClockPosition.bottom;
      case 'center':
        return ClockPosition.center;
      case 'custom':
        if (customY == null) return ClockPosition.center;
        if (customY < 1 / 3) return ClockPosition.top;
        if (customY > 2 / 3) return ClockPosition.bottom;
        return ClockPosition.center;
      default:
        return ClockPosition.center;
    }
  }

  static ClockDatePosition _datePositionFrom(Object? raw) =>
      raw == 'above' ? ClockDatePosition.above : ClockDatePosition.below;

  static ClockTimeLayout _timeLayoutFrom(Object? raw) =>
      switch (raw is String ? raw.trim() : null) {
        'inline' => ClockTimeLayout.inline,
        'stacked' => ClockTimeLayout.stacked,
        'stackedCompact' => ClockTimeLayout.stackedCompact,
        'offsetStack' => ClockTimeLayout.offsetStack,
        'verticalPoster' => ClockTimeLayout.verticalPoster,
        _ => ClockTimeLayout.inline,
      };

  /// `auto` (derive a colour from the picture) is read as `single`, so
  /// `color` is what draws.
  static ClockColorMode _colorModeFrom(Object? raw) =>
      switch (raw is String ? raw.trim() : null) {
        'split' => ClockColorMode.split,
        'gradient' => ClockColorMode.gradient,
        _ => ClockColorMode.single,
      };

  static ClockColonColor _colonColorFrom(Object? raw) =>
      switch (raw is String ? raw.trim() : null) {
        'minutes' => ClockColonColor.minutes,
        'custom' => ClockColonColor.custom,
        _ => ClockColonColor.hours,
      };

  static ClockWeight _weightPresetFrom(Object? raw) =>
      switch (raw is String ? raw.trim() : null) {
        'extraLight' => ClockWeight.extraLight,
        'light' => ClockWeight.light,
        'regular' => ClockWeight.regular,
        'medium' => ClockWeight.medium,
        'semiBold' => ClockWeight.semiBold,
        'bold' => ClockWeight.bold,
        'extraBold' => ClockWeight.extraBold,
        'black' => ClockWeight.black,
        _ => ClockWeight.regular,
      };

  // --- defensive readers -------------------------------------------------

  /// Reads a string field, tolerating a backend that sends a number, a list
  /// or anything else where a string was expected.
  static String? _string(Object? v) => v is String ? v : null;

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  /// Reads a CSS-authored colour (`#RRGGBB` / `#RRGGBBAA`) into ARGB, tolerating
  /// a non-string value. Returns null when absent or unparseable, which every
  /// caller reads as "not authored".
  static int? _color(Object? v) => parseCssHexColorToArgb(_string(v));

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  static double _double(
    Object? v,
    double fallback, {
    required double min,
    required double max,
  }) => v is num && v.toDouble().isFinite
      ? v.toDouble().clamp(min, max)
      : fallback;

  static double? _nullableDouble(
    Object? v, {
    required double min,
    required double max,
  }) => v is num && v.toDouble().isFinite ? v.toDouble().clamp(min, max) : null;

  static int _int(
    Object? v,
    int fallback, {
    required int min,
    required int max,
  }) =>
      v is num && v.toDouble().isFinite ? v.toInt().clamp(min, max) : fallback;
}
