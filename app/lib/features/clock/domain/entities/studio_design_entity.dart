import 'package:equatable/equatable.dart';

import 'clock_config_entity.dart';

/// What the dashboard asks the app to do when the user applies a wallpaper.
///
/// Wire values come from `studio.behavior.applyTarget`. `ask` - the only value
/// observed in production - means the app should let the user choose between
/// applying the authored design and applying the bare wallpaper. The other two
/// let the dashboard decide on the user's behalf.
enum StudioApplyTarget {
  /// Offer the user "With Design" / "Wallpaper Only".
  ask,

  /// Always apply the authored design, no prompt.
  withDesign,

  /// Always apply the bare media, no prompt.
  wallpaperOnly,
}

/// How the clock animates in. Only [none] is observed in production; the
/// others are carried so a newer dashboard does not read as malformed.
enum StudioClockEntrance { none, fade, slide, scale }

/// Full-frame photographic treatment applied to the wallpaper image.
///
/// Every scalar is an *offset* where 0 means "leave the image alone", so a
/// default-constructed [StudioScene] is the identity transform - which is what
/// the overwhelming majority of authored wallpapers carry.
class StudioScene extends Equatable {
  const StudioScene({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.exposure = 0,
    this.sharpen = 0,
    this.blur = 0,
    this.vignetteAmount = 0,
    this.vignetteSoftness = 0.5,
    this.grainAmount = 0,
    this.grainSize = 1,
    this.gradientOverlay,
    this.tint,
    this.duotone,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double exposure;
  final double sharpen;
  final double blur;
  final double vignetteAmount;
  final double vignetteSoftness;
  final double grainAmount;
  final double grainSize;
  final StudioGradientOverlay? gradientOverlay;
  final StudioTint? tint;
  final StudioDuotone? duotone;

  /// True when this scene would visibly change the image. A scene that is
  /// entirely at its identity values is equivalent to having no scene at all,
  /// and must not on its own make a wallpaper count as "designed".
  bool get hasVisibleEffect =>
      brightness != 0 ||
      contrast != 0 ||
      saturation != 0 ||
      warmth != 0 ||
      exposure != 0 ||
      sharpen != 0 ||
      blur != 0 ||
      vignetteAmount != 0 ||
      grainAmount != 0 ||
      (gradientOverlay?.enabled ?? false) ||
      (tint?.enabled ?? false) ||
      (duotone?.enabled ?? false);

  @override
  List<Object?> get props => [
    brightness,
    contrast,
    saturation,
    warmth,
    exposure,
    sharpen,
    blur,
    vignetteAmount,
    vignetteSoftness,
    grainAmount,
    grainSize,
    gradientOverlay,
    tint,
    duotone,
  ];
}

class StudioGradientOverlay extends Equatable {
  const StudioGradientOverlay({
    required this.enabled,
    required this.from,
    required this.to,
    this.angleDeg = 180,
    this.opacity = 0.5,
    this.blendMode = 'normal',
  });

  final bool enabled;

  /// ARGB.
  final int from;

  /// ARGB.
  final int to;
  final double angleDeg;
  final double opacity;
  final String blendMode;

  @override
  List<Object?> get props => [enabled, from, to, angleDeg, opacity, blendMode];
}

class StudioTint extends Equatable {
  const StudioTint({
    required this.enabled,
    required this.color,
    this.opacity = 0.2,
    this.blendMode = 'soft-light',
  });

  final bool enabled;

  /// ARGB.
  final int color;
  final double opacity;
  final String blendMode;

  @override
  List<Object?> get props => [enabled, color, opacity, blendMode];
}

class StudioDuotone extends Equatable {
  const StudioDuotone({
    required this.enabled,
    required this.shadow,
    required this.highlight,
  });

  final bool enabled;

  /// ARGB.
  final int shadow;

  /// ARGB.
  final int highlight;

  @override
  List<Object?> get props => [enabled, shadow, highlight];
}

/// A date element positioned independently of the clock.
///
/// This is NOT the clock's own nested `date` (which sits directly above or
/// below the time); it is a separate element with its own coordinates, font
/// and scale.
class StudioDateWidget extends Equatable {
  const StudioDateWidget({
    this.enabled = false,
    this.format = 'medium',
    this.pattern,
    this.locale = 'en',
    this.position = 'bottom',
    this.customX,
    this.customY,
    this.color = 0xFFFFFFFF,
    this.scale = 1.0,
    this.font = 'Inter',
    this.weight = 400,
    this.uppercase = false,
  });

  final bool enabled;

  /// `short` / `medium` / `long`, or a custom [pattern] when one is authored.
  final String format;

  /// An explicit date pattern which, when present, overrides [format].
  final String? pattern;

  /// The locale the date is authored to read in.
  final String locale;
  final String position;
  final double? customX;
  final double? customY;

  /// ARGB.
  final int color;
  final double scale;
  final String font;
  final int weight;
  final bool uppercase;

  bool get hasCustomPosition => customX != null && customY != null;

  @override
  List<Object?> get props => [
    enabled,
    format,
    pattern,
    locale,
    position,
    customX,
    customY,
    color,
    scale,
    font,
    weight,
    uppercase,
  ];
}

/// A studio widget the app knows how to render.
///
/// The backend's `kind` vocabulary is open-ended, so an unrecognised kind is
/// dropped at parse time rather than represented here - see
/// [StudioDesign.unsupportedWidgetKinds] for what was skipped.
sealed class StudioWidget extends Equatable {
  const StudioWidget({
    required this.customX,
    required this.customY,
    required this.color,
    required this.scale,
    required this.rotation,
    required this.anchor,
  });

  final double? customX;
  final double? customY;

  /// ARGB.
  final int color;
  final double scale;
  final double rotation;
  final String anchor;

  /// Whether this widget's rendered content changes at runtime. A widget that
  /// does is what forces a live wallpaper rather than a baked bitmap.
  bool get isDynamic;
}

/// A ring showing the device's current battery level.
///
/// Reads the local battery level only - no permission is required for this on
/// Android, and none is requested.
class StudioBatteryRing extends StudioWidget {
  const StudioBatteryRing({
    super.customX,
    super.customY,
    super.color = 0xFFFFFFFF,
    super.scale = 1.0,
    super.rotation = 0,
    super.anchor = 'top',
    this.showPercentage = true,
  });

  final bool showPercentage;

  /// Battery level changes while the wallpaper is on screen, so this element
  /// cannot be baked into a static bitmap.
  @override
  bool get isDynamic => true;

  @override
  List<Object?> get props => [
    customX,
    customY,
    color,
    scale,
    rotation,
    anchor,
    showPercentage,
  ];
}

/// How the app must render a design in order to stay faithful to it.
enum DesignRenderMode {
  /// Nothing authored - apply the media exactly as it is.
  none,

  /// Every authored element is fixed, so the design can be composed once into
  /// a bitmap and applied through the ordinary static wallpaper path.
  static_,

  /// At least one element changes at runtime (a ticking clock, a battery
  /// ring), so the design needs the live wallpaper engine.
  dynamic_,
}

/// The dashboard-authored design for one wallpaper, fully typed.
///
/// A wallpaper carries at most one of these. Absent (or present but empty)
/// means the wallpaper has no authored design and must render exactly as it
/// always did.
class StudioDesign extends Equatable {
  const StudioDesign({
    this.clock,
    this.scene,
    this.dateWidget,
    this.widgets = const [],
    this.applyTarget = StudioApplyTarget.ask,
    this.clockEntrance = StudioClockEntrance.none,
    this.clockEntranceMs = 600,
    this.styledPreviewUrl,
    this.unsupportedWidgetKinds = const [],
  });

  /// The authored clock, from `studio.clock` or the legacy top-level
  /// `clockConfig` - whichever the backend supplied (see
  /// `WallpaperModel.toEntity`).
  final ClockConfigEntity? clock;

  final StudioScene? scene;
  final StudioDateWidget? dateWidget;
  final List<StudioWidget> widgets;
  final StudioApplyTarget applyTarget;
  final StudioClockEntrance clockEntrance;
  final int clockEntranceMs;

  /// A server-rendered composite of the finished design. Useful as a
  /// lightweight preview; never a substitute for rendering a live element.
  final String? styledPreviewUrl;

  /// `kind` values the backend sent that this build does not render. Kept for
  /// diagnostics so a newer backend element is visibly skipped rather than
  /// silently forgotten.
  final List<String> unsupportedWidgetKinds;

  /// Whether the wallpaper has any authored design worth rendering.
  ///
  /// A clock that is authored but `enabled: false` does not count, nor does a
  /// scene whose every value is the identity transform - both mean the author
  /// deliberately shipped the wallpaper bare.
  bool get hasDesign =>
      (clock?.enabled ?? false) ||
      (scene?.hasVisibleEffect ?? false) ||
      (dateWidget?.enabled ?? false) ||
      widgets.isNotEmpty;

  /// Whether any authored element changes at runtime.
  ///
  /// A clock displays the current time, so an enabled clock is always dynamic.
  /// A scene, and a date that only changes at midnight, are not: they can be
  /// composed once.
  bool get isDynamic =>
      (clock?.enabled ?? false) || widgets.any((w) => w.isDynamic);

  /// How this design must be rendered to stay faithful to what was authored.
  DesignRenderMode get renderMode {
    if (!hasDesign) return DesignRenderMode.none;
    return isDynamic ? DesignRenderMode.dynamic_ : DesignRenderMode.static_;
  }

  @override
  List<Object?> get props => [
    clock,
    scene,
    dateWidget,
    widgets,
    applyTarget,
    clockEntrance,
    clockEntranceMs,
    styledPreviewUrl,
    unsupportedWidgetKinds,
  ];
}
