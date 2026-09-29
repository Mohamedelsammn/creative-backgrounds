import '../../../../core/utils/color_utils.dart';
import '../../domain/entities/studio_design_entity.dart';
import 'remote_clock_config_mapper.dart';

/// Translates the backend's `studio` object into a [StudioDesign].
///
/// The backend authors a wallpaper's design in one of two generations (see
/// `docs/DESIGN_RENDERING_CONTRACT.md` §1.2):
///
///  * current - `studio.clock` plus `studio.scene` / `dateWidget` / `widgets`
///  * legacy  - a top-level `clockConfig`, with no `studio` at all
///
/// They are not mutually exclusive: a wallpaper can carry `studio` with a
/// **null** `studio.clock` while its real clock sits in the legacy
/// `clockConfig` (observed in production). [fromJson] therefore takes both
/// containers and applies the documented precedence rather than assuming that
/// the presence of `studio` means the legacy field can be ignored.
///
/// Everything is read defensively. A malformed optional design must never take
/// down the wallpaper it belongs to, and an unknown widget `kind` from a newer
/// backend is skipped (and recorded in
/// [StudioDesign.unsupportedWidgetKinds]) rather than treated as an error.
class StudioDesignMapper {
  const StudioDesignMapper._();

  /// Builds the canonical design for one wallpaper.
  ///
  /// [studio] is the backend's `studio` object; [legacyClockConfig] is the
  /// top-level `clockConfig`. Returns null when neither carries anything - the
  /// caller reads that as "this wallpaper has no authored design".
  ///
  /// Clock precedence: `studio.clock` wins when present, otherwise the legacy
  /// `clockConfig` is used. Both are parsed by [RemoteClockConfigMapper], which
  /// reads either generation, because the two share 45 identically-shaped
  /// fields.
  static StudioDesign? fromJson(Object? studio, {Object? legacyClockConfig}) {
    final map = studio is Map ? Map<String, dynamic>.from(studio) : null;

    final clock =
        RemoteClockConfigMapper.fromJson(map?['clock']) ??
        RemoteClockConfigMapper.fromJson(legacyClockConfig);

    if (map == null) {
      // No studio at all: a legacy wallpaper. It still gets a design when it
      // authored a clock, so every downstream consumer has one shape to read.
      if (clock == null) return null;
      return StudioDesign(clock: clock);
    }

    final behavior = map['behavior'];
    final widgets = _widgets(map['widgets']);

    return StudioDesign(
      clock: clock,
      scene: _scene(map['scene']),
      dateWidget: _dateWidget(map['dateWidget']),
      widgets: widgets.supported,
      unsupportedWidgetKinds: widgets.unsupportedKinds,
      applyTarget: _applyTarget(
        behavior is Map ? behavior['applyTarget'] : null,
      ),
      clockEntrance: _clockEntrance(
        behavior is Map ? behavior['clockEntrance'] : null,
      ),
      clockEntranceMs: behavior is Map
          ? _int(behavior['clockEntranceMs'], 600, min: 0, max: 10000)
          : 600,
      styledPreviewUrl: _nonEmptyString(map['styledPreviewUrl']),
    );
  }

  // --- scene -------------------------------------------------------------

  static StudioScene? _scene(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final vignette = map['vignette'];
    final grain = map['grain'];

    final scene = StudioScene(
      brightness: _double(map['brightness'], 0, min: -1, max: 1),
      contrast: _double(map['contrast'], 0, min: -1, max: 1),
      saturation: _double(map['saturation'], 0, min: -1, max: 1),
      warmth: _double(map['warmth'], 0, min: -1, max: 1),
      exposure: _double(map['exposure'], 0, min: -1, max: 1),
      sharpen: _double(map['sharpen'], 0, min: 0, max: 1),
      blur: _double(map['blur'], 0, min: 0, max: 1),
      vignetteAmount: vignette is Map
          ? _double(vignette['amount'], 0, min: 0, max: 1)
          : 0,
      vignetteSoftness: vignette is Map
          ? _double(vignette['softness'], 0.5, min: 0, max: 1)
          : 0.5,
      grainAmount: grain is Map
          ? _double(grain['amount'], 0, min: 0, max: 1)
          : 0,
      grainSize: grain is Map ? _double(grain['size'], 1, min: 0, max: 10) : 1,
      gradientOverlay: _gradientOverlay(map['gradientOverlay']),
      tint: _tint(map['tint']),
      duotone: _duotone(map['duotone']),
    );

    // A scene entirely at its identity values is indistinguishable from no
    // scene; collapsing it here keeps `hasDesign` honest downstream.
    return scene.hasVisibleEffect ? scene : null;
  }

  static StudioGradientOverlay? _gradientOverlay(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return StudioGradientOverlay(
      enabled: _bool(map['enabled'], false),
      from: _color(map['from']) ?? 0x00000000,
      to: _color(map['to']) ?? 0xFF000000,
      angleDeg: _double(map['angleDeg'], 180, min: 0, max: 360),
      opacity: _double(map['opacity'], 0.5, min: 0, max: 1),
      blendMode: _nonEmptyString(map['blendMode']) ?? 'normal',
    );
  }

  static StudioTint? _tint(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return StudioTint(
      enabled: _bool(map['enabled'], false),
      color: _color(map['color']) ?? 0xFF000000,
      opacity: _double(map['opacity'], 0.2, min: 0, max: 1),
      blendMode: _nonEmptyString(map['blendMode']) ?? 'soft-light',
    );
  }

  static StudioDuotone? _duotone(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return StudioDuotone(
      enabled: _bool(map['enabled'], false),
      shadow: _color(map['shadow']) ?? 0xFF000000,
      highlight: _color(map['highlight']) ?? 0xFFFFFFFF,
    );
  }

  // --- date widget -------------------------------------------------------

  static StudioDateWidget? _dateWidget(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return StudioDateWidget(
      enabled: _bool(map['enabled'], false),
      format: _nonEmptyString(map['format']) ?? 'medium',
      pattern: _nonEmptyString(map['pattern']),
      locale: _nonEmptyString(map['locale']) ?? 'en',
      position: _nonEmptyString(map['position']) ?? 'bottom',
      customX: _nullableDouble(map['customX'], min: 0, max: 1),
      customY: _nullableDouble(map['customY'], min: 0, max: 1),
      color: _color(map['color']) ?? 0xFFFFFFFF,
      scale: _double(map['scale'], 1.0, min: 0.1, max: 5),
      font: _nonEmptyString(map['font']) ?? 'Inter',
      weight: _int(map['weight'], 400, min: 100, max: 900),
      uppercase: _bool(map['uppercase'], false),
    );
  }

  // --- widgets -----------------------------------------------------------

  static ({List<StudioWidget> supported, List<String> unsupportedKinds})
  _widgets(Object? raw) {
    if (raw is! List) return (supported: const [], unsupportedKinds: const []);

    final supported = <StudioWidget>[];
    final unsupported = <String>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final kind = _nonEmptyString(map['kind']);
      if (kind == null) continue;

      switch (kind) {
        case 'batteryRing':
          supported.add(
            StudioBatteryRing(
              customX: _nullableDouble(map['customX'], min: 0, max: 1),
              customY: _nullableDouble(map['customY'], min: 0, max: 1),
              color: _color(map['color']) ?? 0xFFFFFFFF,
              scale: _double(map['scale'], 1.0, min: 0.1, max: 5),
              rotation: _double(map['rotation'], 0, min: -180, max: 180),
              anchor: _nonEmptyString(map['anchor']) ?? 'top',
              showPercentage: _bool(map['showPercentage'], true),
            ),
          );
        default:
          // A newer backend element this build cannot draw. Skipping it keeps
          // the rest of the design renderable; recording it makes the gap
          // visible instead of silent.
          if (!unsupported.contains(kind)) unsupported.add(kind);
      }
    }

    return (supported: supported, unsupportedKinds: unsupported);
  }

  // --- behavior ----------------------------------------------------------

  static StudioApplyTarget _applyTarget(Object? raw) =>
      switch (_nonEmptyString(raw)) {
        'withDesign' || 'design' => StudioApplyTarget.withDesign,
        'wallpaperOnly' || 'wallpaper' => StudioApplyTarget.wallpaperOnly,
        // `ask` is the documented default and the only value seen in
        // production; an unknown mode falls back to asking, which is the
        // option that never overrides the user's intent.
        _ => StudioApplyTarget.ask,
      };

  static StudioClockEntrance _clockEntrance(Object? raw) =>
      switch (_nonEmptyString(raw)) {
        'fade' => StudioClockEntrance.fade,
        'slide' => StudioClockEntrance.slide,
        'scale' => StudioClockEntrance.scale,
        _ => StudioClockEntrance.none,
      };

  // --- defensive readers -------------------------------------------------

  static String? _nonEmptyString(Object? v) {
    if (v is! String) return null;
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _color(Object? v) => parseCssHexColorToArgb(_nonEmptyString(v));

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
