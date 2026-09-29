import 'package:equatable/equatable.dart';

enum ClockStyle {
  modern,
  minimal,
  elegant,
  digital,
  condensed,
  poster,
  outline,
  split,
  futuristic,
  editorial,
  monument,
  stencil,
  soft,
}

enum ClockPosition { top, center, bottom }

enum ClockFont { inter, serif, mono, oswald, archivoBlack, anton }

/// Where the date sits relative to the time. Authored by the backend.
enum ClockDatePosition { above, below }

/// Preset font-weight steps, shown to the user as named options ("Bold",
/// "Extra Light", ...) rather than a raw 100-900 number - the raw
/// backend-authored [ClockConfigEntity.weight] int still exists separately
/// and is unaffected; this is the *local* typography control the brief calls
/// for. Maps to a concrete [FontWeight]/native weight int via
/// `ClockStylePreset`'s weight table, never hardcoded at the call site.
enum ClockWeight {
  extraLight,
  light,
  regular,
  medium,
  semiBold,
  bold,
  extraBold,
  black,
}

/// How the hour/minute digits are arranged. [inline] is today's only
/// behavior ("12:45" as one line); the rest are new compositions - see
/// `ClockLayoutEngine`.
enum ClockTimeLayout {
  inline,
  stacked,
  stackedCompact,
  offsetStack,
  verticalPoster,
}

/// How the time is coloured. `auto` (derive from the picture) is read as
/// [single] by the mapper, falling back to `color`.
enum ClockColorMode { single, split, gradient }

/// `behind` paints the stroke first so only its outer half shows; `front`
/// paints the full stroke over the fill.
enum ClockStrokeOrder { behind, front }

/// Which edge of the time block the fade mask ramps to transparent at.
enum ClockFadeDirection { bottom, top, both }

/// A studio clock's 12/24 hour choice. `auto` follows the phone's setting.
enum ClockHourFormat { h12, h24, auto }

/// Which color the ":" separator uses in [ClockColorMode.split] +
/// [ClockTimeLayout.inline] (the only combination where a colon can even be
/// visible and split-colored at once). Defaults to [hours] - the brief's own
/// "default it intelligently" guidance - so turning on split mode never
/// requires a fourth decision before it looks right.
enum ClockColonColor { hours, minutes, custom }

/// All configurable clock properties. Rendered identically by the Flutter
/// preview (`ClockPainter`) and the native `ClockRenderer.kt`.
///
/// Fields fall into three groups:
///
///  * **Rendered today** — [style], [position], [font], [color], [sizePx],
///    [opacity], [showShadow], [showGlow], [showStroke], [is24Hour],
///    [showDate], [showSeconds].
///  * **Backend-authored, carried verbatim** — [remoteStyle], [remoteFont],
///    [weight], [rotation], [scale], [depth], [shadowStrength], [datePosition],
///    [dateColor], [customX], [customY], [schemaVersion]. These come from the
///    dashboard's clock configuration. They are preserved end-to-end so nothing
///    the content team authored is lost, and are progressively honored by the
///    renderers.
///  * **User-only** — [is24Hour] and [showSeconds] have no backend counterpart;
///    they are personal preferences, not content.
///
/// [remoteStyle]/[remoteFont] hold the raw backend strings because the backend
/// vocabulary is wider than this app's enums (8 styles vs 4, free-form font
/// names vs 3 bundled families). [style]/[font] are the nearest supported
/// match, used by the existing UI; the raw values let a renderer do better.
class ClockConfigEntity extends Equatable {
  const ClockConfigEntity({
    this.style = ClockStyle.modern,
    this.position = ClockPosition.top,
    this.font = ClockFont.inter,
    this.color = 0xFFFFFFFF,
    this.sizePx = 65,
    this.opacity = 1.0,
    this.showShadow = true,
    this.showGlow = false,
    this.showStroke = false,
    this.is24Hour = false,
    this.showDate = true,
    this.showSeconds = false,
    this.enabled = true,
    this.remoteStyle,
    this.remoteFont,
    this.weight = 400,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.depth = 0.45,
    this.shadowStrength = 0.5,
    this.datePosition = ClockDatePosition.below,
    this.dateColor,
    this.customX,
    this.customY,
    this.schemaVersion = 1,
    this.stretchY = 1.0,
    this.dateScale = 1.0,
    this.fontWeightPreset = ClockWeight.regular,
    this.horizontalScale = 1.0,
    this.timeLayout = ClockTimeLayout.inline,
    this.showColon = true,
    this.lineSpacing = 1.0,
    this.minuteOffsetX = 0.0,
    this.colorMode = ClockColorMode.single,
    this.hoursColor,
    this.minutesColor,
    this.colonColor = ClockColonColor.hours,
    this.colonColorCustom,
    this.strokeWidth = 2.0,
    this.showAmPm = false,
    this.gradientFrom,
    this.gradientTo,
    this.gradientAngleDeg = 180,
    this.fillOpacity = 1.0,
    this.hoursFont,
    this.minutesFont,
    this.strokeColor = 0xFF000000,
    this.strokeOrder = ClockStrokeOrder.behind,
    this.fadeAmount = 0,
    this.fadeDirection = ClockFadeDirection.bottom,
    this.blur = 0,
    this.hourFormat,
  });

  final ClockStyle style;
  final ClockPosition position;

  /// Overrides the font family the [style] preset would otherwise imply.
  final ClockFont font;

  final int color; // ARGB
  final double sizePx; // 24–120
  final double opacity; // 0.0–1.0
  final bool showShadow;
  final bool showGlow;
  final bool showStroke;
  final bool is24Hour;

  /// Whether to append an AM/PM suffix to a 12-hour time.
  ///
  /// Backend-authored. Ignored when [is24Hour] (where it is meaningless) and
  /// by the stacked layouts, which split hours and minutes onto separate rows
  /// and have no defined slot for a suffix - no production wallpaper pairs
  /// `showAmPm` with a stacked layout.
  final bool showAmPm;

  final bool showDate;
  final bool showSeconds;

  /// Whether the wallpaper shows a clock at all. Backend-authored; a depth
  /// wallpaper may deliberately ship without one.
  final bool enabled;

  /// Raw backend style id (`outlined`, `solid`, `thin`, `bold`, `classic`,
  /// `rounded`, …). Null for a purely local config.
  final String? remoteStyle;

  /// Raw backend font family name (e.g. `BebasNeue`). Null for a local config.
  final String? remoteFont;

  /// Variable-font weight axis, 100–900.
  final int weight;

  /// Backend size multiplier, 0.5–3.0. [sizePx] is derived from this.
  final double scale;

  /// Degrees, -180–180.
  final double rotation;

  /// How deep the clock sits in the depth stack, 0.0–1.0.
  final double depth;

  /// Drop-shadow strength, 0.0–1.0. Only meaningful when [showShadow].
  final double shadowStrength;

  final ClockDatePosition datePosition;

  /// ARGB date color. Falls back to [color] when null.
  final int? dateColor;

  /// Normalized 0.0–1.0 placement when the backend authored an exact position.
  ///
  /// The backend's `position: "custom"` is mapped to the nearest of
  /// top/center/bottom for [position] so the existing three-way UI keeps
  /// working; these hold the exact coordinates for renderers that can honor
  /// them.
  final double? customX;
  final double? customY;

  /// Backend config schema version, carried for forward compatibility.
  final int schemaVersion;

  /// Vertical stretch applied on top of [sizePx], independent of width.
  ///
  /// User-only (no backend counterpart, hence no `remote` gating): lets the
  /// clock be made dramatically taller - approaching a tall, narrow numeral
  /// look - without proportionally widening it, which would otherwise force
  /// [sizePx] so large the digits blow past the sides of the wallpaper.
  /// 1.0 is the identity transform, so every existing saved/backend config
  /// renders exactly as before. Range 1.0-3.0; never below 1.0, since
  /// *shrinking* vertically belongs to [sizePx] (uniform), not this axis.
  final double stretchY;

  /// Independent multiplier on the date's font size, applied on top of the
  /// existing `(sizePx * 0.22).clamp(14, 24)` derivation - lets the user make
  /// the date noticeably bigger/smaller relative to the time without that
  /// base relationship changing (so an unedited/backend config renders
  /// exactly as before at 1.0). User-only, mirroring [stretchY]. Range
  /// 0.5-2.0.
  final double dateScale;

  /// Named weight preset (Extra Light .. Black) shown in the Typography
  /// control - distinct from the raw backend [weight] int. `regular` maps to
  /// the same weight the existing style-derived lookup already produces, so
  /// an unedited config renders exactly as before. See `ClockStylePreset`
  /// for the preset->FontWeight table.
  final ClockWeight fontWeightPreset;

  /// Horizontal-only typography scale - "Width" in the editor. 1.0 is the
  /// identity transform. Unlike [stretchY] (vertical, glyph height) or
  /// [sizePx] (uniform), this scales ONLY the X axis, so condensed/wide
  /// looks are reachable without changing how tall the numerals are. Range
  /// 0.55-1.50.
  final double horizontalScale;

  /// How the hour/minute digits are arranged - see [ClockTimeLayout].
  /// `inline` reproduces today's only behavior exactly.
  final ClockTimeLayout timeLayout;

  /// Whether the ":" separator is drawn in [ClockTimeLayout.inline]. Ignored
  /// by every stacked layout, which never shows a colon regardless of this
  /// flag (per design: two rows already read as a single time without one).
  final bool showColon;

  /// Multiplier on the gap between rows in a stacked layout, on top of that
  /// layout's own base gap - mirrors [dateScale]'s "independent multiplier,
  /// 1.0 is identity" shape. Ignored by `inline`.
  final double lineSpacing;

  /// Horizontal offset of the second (minute) row in
  /// [ClockTimeLayout.offsetStack], as a fraction of the block's own width.
  /// 0.0 keeps both rows centered on the same axis (no offset). Ignored by
  /// every other layout.
  final double minuteOffsetX;

  /// Single time color vs independently-colored hours/minutes - see
  /// [ClockColorMode].
  final ClockColorMode colorMode;

  /// Hours color in [ClockColorMode.split]. Falls back to [color] when null,
  /// so turning on split mode with no color chosen yet still renders
  /// sensibly instead of transparent/black text.
  final int? hoursColor;

  /// Minutes color in [ClockColorMode.split]. Falls back to [color] when
  /// null, mirroring [hoursColor].
  final int? minutesColor;

  /// Which color the inline colon separator uses in split mode - see
  /// [ClockColonColor].
  final ClockColonColor colonColor;

  /// Explicit ARGB colon color when [colonColor] is
  /// [ClockColonColor.custom]. Ignored otherwise.
  final int? colonColorCustom;

  /// Stroke width in logical pixels, applied when [showStroke] is on.
  /// Replaces the previous hardcoded `2.0` constant with a user/style-
  /// adjustable value; 2.0 is the exact prior behavior, so an unedited
  /// config renders identically. The [ClockStyle.outline] style raises this
  /// well above the default as part of its preset.
  final double strokeWidth;

  /// [ClockColorMode.gradient] ends, ARGB. Fall back to [color].
  final int? gradientFrom;
  final int? gradientTo;

  /// CSS angle convention: 0 bottom→top, 90 left→right, 180 top→bottom.
  final double gradientAngleDeg;

  /// Multiplies the alpha of the digits' fill only - never the stroke.
  final double fillOpacity;

  /// Font names replacing the family for the hours / minutes half only.
  final String? hoursFont;
  final String? minutesFont;

  final int strokeColor;
  final ClockStrokeOrder strokeOrder;

  /// Fade mask over the time block (not the date), 0-1.
  final double fadeAmount;
  final ClockFadeDirection fadeDirection;

  /// Gaussian blur of the time (not the date), 0-20 at the reference size.
  final double blur;

  /// Studio clocks only; null means use [is24Hour] (depth clocks).
  final ClockHourFormat? hourFormat;

  /// Whether the clock is stretched taller than its natural proportions.
  bool get isStretched => stretchY > 1.0;

  /// True when the backend authored an exact position rather than an anchor.
  bool get hasCustomPosition => customX != null && customY != null;

  /// The clock's current effective centre, as a normalized 0.0-1.0 fraction
  /// of the preview, whether it comes from an exact drag/authored position or
  /// from the anchor. Ignores [blockHeight] deliberately (this is only ever
  /// used as a *starting point* for a drag gesture, not the final rendered
  /// position - the renderers' own bounds-aware math is what actually places
  /// the pixels), so the anchor's approximate midpoint is accurate enough.
  double get effectiveNormalizedX => hasCustomPosition ? customX! : 0.5;

  double get effectiveNormalizedY {
    if (hasCustomPosition) return customY!;
    return switch (position) {
      ClockPosition.top => 0.14,
      ClockPosition.center => 0.5,
      ClockPosition.bottom => 0.78,
    };
  }

  /// True when this configuration originated from the backend rather than from
  /// local defaults alone.
  ///
  /// Renderers use this to decide whether to honor the backend-only fields
  /// ([weight], [rotation], [shadowStrength], ...). Without the guard a purely
  /// local config would suddenly render at `weight: 400` instead of the weight
  /// its [style] implies - a visual regression for every existing user.
  bool get isRemote => remoteStyle != null || remoteFont != null;

  ClockConfigEntity copyWith({
    ClockStyle? style,
    ClockPosition? position,
    ClockFont? font,
    int? color,
    double? sizePx,
    double? opacity,
    bool? showShadow,
    bool? showGlow,
    bool? showStroke,
    bool? is24Hour,
    bool? showDate,
    bool? showSeconds,
    bool? enabled,
    String? remoteStyle,
    String? remoteFont,
    int? weight,
    double? scale,
    double? rotation,
    double? depth,
    double? shadowStrength,
    ClockDatePosition? datePosition,
    int? dateColor,
    double? customX,
    double? customY,
    int? schemaVersion,
    double? stretchY,
    double? dateScale,
    ClockWeight? fontWeightPreset,
    double? horizontalScale,
    ClockTimeLayout? timeLayout,
    bool? showColon,
    double? lineSpacing,
    double? minuteOffsetX,
    ClockColorMode? colorMode,
    int? hoursColor,
    int? minutesColor,
    ClockColonColor? colonColor,
    int? colonColorCustom,
    double? strokeWidth,
    bool? showAmPm,
    int? gradientFrom,
    int? gradientTo,
    double? gradientAngleDeg,
    double? fillOpacity,
    String? hoursFont,
    String? minutesFont,
    int? strokeColor,
    ClockStrokeOrder? strokeOrder,
    double? fadeAmount,
    ClockFadeDirection? fadeDirection,
    double? blur,
    ClockHourFormat? hourFormat,

    /// When true, [customX]/[customY] are reset to null regardless of the
    /// values passed above - the only way to clear an authored exact
    /// position, since the normal `??` pattern can never set a field back to
    /// null. Used when the user picks the anchor-based Top/Center/Bottom
    /// position after having dragged the clock to an exact spot, so exactly
    /// one of "anchor" or "exact position" is ever in effect at a time.
    bool clearCustomPosition = false,

    /// When true, [remoteStyle]/[remoteFont] are reset to null regardless of
    /// the values passed above. Used when the user picks a style manually
    /// from the Styles tab: that is a deliberate override of the backend's
    /// authored look, not a tweak on top of it, so [isRemote] must go back to
    /// false and the renderers must derive weight/tracking from the newly
    /// chosen [ClockStyle] - not keep applying the old backend [weight] /
    /// [shadowStrength] under a style the backend never authored.
    bool clearRemoteAuthorship = false,
  }) {
    return ClockConfigEntity(
      style: style ?? this.style,
      position: position ?? this.position,
      font: font ?? this.font,
      color: color ?? this.color,
      sizePx: sizePx ?? this.sizePx,
      opacity: opacity ?? this.opacity,
      showShadow: showShadow ?? this.showShadow,
      showGlow: showGlow ?? this.showGlow,
      showStroke: showStroke ?? this.showStroke,
      is24Hour: is24Hour ?? this.is24Hour,
      showDate: showDate ?? this.showDate,
      showSeconds: showSeconds ?? this.showSeconds,
      enabled: enabled ?? this.enabled,
      remoteStyle: clearRemoteAuthorship
          ? null
          : (remoteStyle ?? this.remoteStyle),
      remoteFont: clearRemoteAuthorship
          ? null
          : (remoteFont ?? this.remoteFont),
      weight: weight ?? this.weight,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      depth: depth ?? this.depth,
      shadowStrength: shadowStrength ?? this.shadowStrength,
      datePosition: datePosition ?? this.datePosition,
      dateColor: dateColor ?? this.dateColor,
      customX: clearCustomPosition ? null : (customX ?? this.customX),
      customY: clearCustomPosition ? null : (customY ?? this.customY),
      schemaVersion: schemaVersion ?? this.schemaVersion,
      stretchY: stretchY ?? this.stretchY,
      dateScale: dateScale ?? this.dateScale,
      fontWeightPreset: fontWeightPreset ?? this.fontWeightPreset,
      horizontalScale: horizontalScale ?? this.horizontalScale,
      timeLayout: timeLayout ?? this.timeLayout,
      showColon: showColon ?? this.showColon,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      minuteOffsetX: minuteOffsetX ?? this.minuteOffsetX,
      colorMode: colorMode ?? this.colorMode,
      hoursColor: hoursColor ?? this.hoursColor,
      minutesColor: minutesColor ?? this.minutesColor,
      colonColor: colonColor ?? this.colonColor,
      colonColorCustom: colonColorCustom ?? this.colonColorCustom,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      showAmPm: showAmPm ?? this.showAmPm,
      gradientFrom: gradientFrom ?? this.gradientFrom,
      gradientTo: gradientTo ?? this.gradientTo,
      gradientAngleDeg: gradientAngleDeg ?? this.gradientAngleDeg,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      hoursFont: hoursFont ?? this.hoursFont,
      minutesFont: minutesFont ?? this.minutesFont,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeOrder: strokeOrder ?? this.strokeOrder,
      fadeAmount: fadeAmount ?? this.fadeAmount,
      fadeDirection: fadeDirection ?? this.fadeDirection,
      blur: blur ?? this.blur,
      hourFormat: hourFormat ?? this.hourFormat,
    );
  }

  @override
  List<Object?> get props => [
    style,
    position,
    font,
    color,
    sizePx,
    opacity,
    showShadow,
    showGlow,
    showStroke,
    is24Hour,
    showDate,
    showSeconds,
    enabled,
    remoteStyle,
    remoteFont,
    weight,
    scale,
    rotation,
    depth,
    shadowStrength,
    datePosition,
    dateColor,
    customX,
    customY,
    schemaVersion,
    stretchY,
    dateScale,
    fontWeightPreset,
    horizontalScale,
    timeLayout,
    showColon,
    lineSpacing,
    minuteOffsetX,
    colorMode,
    hoursColor,
    minutesColor,
    colonColor,
    colonColorCustom,
    strokeWidth,
    showAmPm,
    gradientFrom,
    gradientTo,
    gradientAngleDeg,
    fillOpacity,
    hoursFont,
    minutesFont,
    strokeColor,
    strokeOrder,
    fadeAmount,
    fadeDirection,
    blur,
    hourFormat,
  ];
}
