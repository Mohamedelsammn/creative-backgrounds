# Depth Wallpaper Dashboard Contract

**Application:** Creative Backgrounds  
**Status:** Implementation handoff based on the current Flutter/Android source  
**Dashboard source:** No Dashboard implementation exists in this repository. Dashboard current status is **Unknown / Requires Dashboard Audit**.

This document distinguishes the payload the current mobile app already consumes from the recommended complete Dashboard contract. The mobile app is the source of truth; do not expose values that are not listed here.

## 1. Supported capability summary

The current editor supports clock style, font, named weight, size, horizontal width, vertical stretch, five time layouts, anchor or dragged position, opacity, shadow/glow/stroke toggles, stroke width, single/split color, colon visibility/color, 12/24-hour mode, seconds, date visibility/position/color/size, and a depth on/off toggle.

Content can also author a depth render configuration: foreground scale, normalized foreground X/Y offsets, background blur radius, and foreground shadow strength. Those values are not user-editable in the current mobile editor.

The following are **not** current features: user image crop/pan/brightness/saturation/contrast/dim controls, gradients, effect color/blur/offset sliders, date-format selection, locale selection, or user foreground geometry controls.

## 2. Canonical values

Use these values in new Dashboard payloads. UI labels are presentation-only.

### Clock

| UI label | Canonical value |
|---|---|
| Modern, Minimal, Elegant, Digital, Condensed, Poster, Outline, Split, Futuristic, Editorial, Monument, Stencil, Soft | `modern`, `minimal`, `elegant`, `digital`, `condensed`, `poster`, `outline`, `split`, `futuristic`, `editorial`, `monument`, `stencil`, `soft` |
| Inter, Serif, Mono, Oswald, Archivo Black, Anton | `inter`, `serif`, `mono`, `oswald`, `archivoBlack`, `anton` |
| Top, Center, Bottom | `top`, `center`, `bottom` |
| Custom position | `custom` in the remote API; local JSON represents it with `customX` and `customY` |
| Inline, Stacked, Compact, Offset, Poster | `inline`, `stacked`, `stackedCompact`, `offsetStack`, `verticalPoster` |
| Single, Split | `single`, `split` |
| Hours, Minutes, Custom colon color | `hours`, `minutes`, `custom` |
| Above, Below | `above`, `below` |

Weight values are `extraLight` (200), `light` (300), `regular` (400), `medium` (500), `semiBold` (600), `bold` (700), `extraBold` (800), and `black` (900). The remote raw `weight` field accepts 100-900 and is clamped by the remote mapper.

Remote compatibility inputs currently recognized by the mobile mapper are `thin` -> `minimal`, `classic` -> `elegant`, and `solid`, `bold`, `rounded`, `outlined`, `modern` -> `modern`. Unknown remote styles fall back visually to `modern` while preserving the raw identifier.

### Preset colors

These are the current opaque swatches. Custom colors use the same `#RRGGBB`/ARGB representation; there is no alpha picker.

| Name | HEX | Name | HEX |
|---|---|---|---|
| Pure White | `#FFFFFF` | Soft White | `#F5F5F5` |
| Light Gray | `#D9D9D9` | Silver | `#C0C0C0` |
| Medium Gray | `#9AA6B2` | Charcoal | `#36393F` |
| Black | `#111111` | Red | `#E53935` |
| Bright Red | `#FF1744` | Crimson | `#DC143C` |
| Burgundy | `#800020` | Coral | `#FF7F6E` |
| Orange | `#FF7A00` | Deep Orange | `#E65100` |
| Amber | `#FFC107` | Copper | `#B87333` |
| Yellow | `#FFEB3B` | Gold | `#FFD700` |
| Warm Gold | `#E1B12C` | Lemon | `#FFF44F` |
| Lime | `#CDDC39` | Green | `#43A047` |
| Emerald | `#50C878` | Mint | `#98FF98` |
| Teal | `#00897B` | Cyan | `#00E5FF` |
| Sky Blue | `#87CEEB` | Blue | `#2196F3` |
| Royal Blue | `#4169E1` | Navy | `#001F54` |
| Purple | `#9C27B0` | Violet | `#8F00FF` |
| Indigo | `#4B0082` | Lavender | `#E6E6FA` |
| Pink | `#F48FB1` | Hot Pink | `#FF69B4` |
| Rose | `#E0BFB8` | Magenta | `#FF00FF` |
| Warm Cream | `#E7D9BE` |  |  |

## 3. Numeric controls and validation

All values below are `double` in Dart/local JSON unless stated otherwise. The editor sliders are continuous: the source does not set a step/division.

| Field | Min | Max | Default | Unit / rule |
|---|---:|---:|---:|---|
| `sizePx` | 24 | 320 | 65 | Flutter logical pixels |
| `horizontalScale` | 0.55 | 1.50 | 1.0 | X scale; Dashboard may display 55-150% |
| `stretchY` | 1.0 | 3.0 | 1.0 | Y scale; Dashboard may display 100-300% |
| `opacity` | 0 | 1 | 1.0 | normalized opacity |
| `lineSpacing` | 0.5 | 2.0 | 1.0 | multiplier; non-inline layouts only |
| `minuteOffsetX` | -1 | 1 | 0 | normalized surface fraction; `offsetStack` only |
| `strokeWidth` | 0.5 | 20 | 2 | logical pixels; only when `showStroke` |
| `dateScale` | 0.5 | 2.0 | 1.0 | multiplier; only when `showDate` |
| `customX` | 0 | 1 | null | normalized clock center X |
| `customY` | 0 | 1 | null | normalized clock center Y |
| remote `weight` | 100 | 900 | 400 | integer variable-font weight |
| remote `scale` | 0.5 | 3 | 1 | mapper derives `sizePx = 76 * scale`, then clamps size to 24-120 |
| remote `rotation` | -180 | 180 | 0 | degrees; remote-authored only |
| clock `shadowStrength` | 0 | 1 | 0.5 | remote clock shadow modulation |
| `foregroundScale` | 0.5 | 3 | 1 | content-authored foreground scale |
| `foregroundOffsetX` / `foregroundOffsetY` | -1 | 1 | 0 | normalized foreground translation |
| `blurRadius` | 0 | 100 | 0 | background blur radius |
| depth `shadowStrength` | 0 | 1 | 0 | content-authored foreground shadow |

No device-specific pixel positions should be sent for `customX`, `customY`, or foreground offsets. Android multiplies clock logical-pixel dimensions by display density; surface dimensions are runtime-specific.

## 4. Default values

The effective built-in clock default is:

```json
{
  "style": "modern",
  "position": "top",
  "font": "inter",
  "color": 4294967295,
  "sizePx": 65.0,
  "opacity": 1.0,
  "showShadow": true,
  "showGlow": false,
  "showStroke": false,
  "is24Hour": false,
  "showDate": true,
  "showSeconds": false,
  "enabled": true,
  "remoteStyle": null,
  "remoteFont": null,
  "weight": 400,
  "scale": 1.0,
  "rotation": 0.0,
  "depth": 0.45,
  "shadowStrength": 0.5,
  "datePosition": "below",
  "dateColor": null,
  "customX": null,
  "customY": null,
  "schemaVersion": 1,
  "stretchY": 1.0,
  "dateScale": 1.0,
  "fontWeightPreset": "regular",
  "horizontalScale": 1.0,
  "timeLayout": "inline",
  "showColon": true,
  "lineSpacing": 1.0,
  "minuteOffsetX": 0.0,
  "colorMode": "single",
  "hoursColor": null,
  "minutesColor": null,
  "colonColor": "hours",
  "colonColorCustom": null,
  "strokeWidth": 2.0
}
```

For a compositable depth wallpaper, depth toggle defaults to enabled only when the wallpaper type is `depth` and both background and foreground URLs are non-empty. Depth render defaults are scale 1, offsets 0, blur 0, and shadow strength 0.

## 5. Current mobile API payload

The existing remote mapper consumes this nested shape. It is not a complete representation of every newer editor field:

```json
{
  "clockConfig": {
    "enabled": true,
    "style": "modern",
    "position": "custom",
    "customX": 0.5,
    "customY": 0.18,
    "font": "Inter",
    "weight": 700,
    "scale": 1.0,
    "rotation": 0,
    "color": "#FFFFFF",
    "opacity": 1.0,
    "depth": 0.45,
    "shadow": {"enabled": true, "strength": 0.5},
    "date": {"enabled": true, "position": "below", "color": "#FFFFFF"},
    "schemaVersion": 1
  },
  "depthConfig": {
    "foregroundScale": 1.0,
    "foregroundOffsetX": 0.0,
    "foregroundOffsetY": 0.0,
    "blurRadius": 0.0,
    "shadowStrength": 0.0
  }
}
```

Current remote ingestion maps only enabled/style/position/custom coordinates/font/weight/scale/rotation/color/opacity/depth/shadow/date/schema version. It does not currently ingest `timeLayout`, split colors, colon options, `stretchY`, `dateScale`, or `strokeWidth` from the backend.

## 6. Recommended complete contract

Use the following as the Dashboard's canonical authoring envelope. It preserves current mobile field names and adds the editor fields the mobile model already persists. This is a recommended contract; the current `RemoteClockConfigMapper` must be extended before these additional fields can be content-authored by the existing app.

```json
{
  "schemaVersion": 1,
  "clockConfig": {
    "enabled": true,
    "style": "modern",
    "position": "top",
    "customX": null,
    "customY": null,
    "font": "inter",
    "fontWeightPreset": "regular",
    "weight": 400,
    "sizePx": 65.0,
    "scale": 1.0,
    "horizontalScale": 1.0,
    "stretchY": 1.0,
    "rotation": 0.0,
    "opacity": 1.0,
    "color": "#FFFFFFFF",
    "colorMode": "single",
    "hoursColor": null,
    "minutesColor": null,
    "colonColor": "hours",
    "colonColorCustom": null,
    "timeLayout": "inline",
    "showColon": true,
    "lineSpacing": 1.0,
    "minuteOffsetX": 0.0,
    "is24Hour": false,
    "showSeconds": false,
    "showDate": true,
    "datePosition": "below",
    "dateColor": null,
    "dateScale": 1.0,
    "showShadow": true,
    "shadowStrength": 0.5,
    "showGlow": false,
    "showStroke": false,
    "strokeWidth": 2.0,
    "depth": 0.45
  },
  "depthConfig": {
    "enabled": true,
    "foregroundScale": 1.0,
    "foregroundOffsetX": 0.0,
    "foregroundOffsetY": 0.0,
    "blurRadius": 0.0,
    "shadowStrength": 0.0
  }
}
```

For compatibility with the current app, a backend may omit fields not currently consumed. The app will use mapper defaults. If the backend sends the complete flat local JSON to the current remote endpoint, the extra fields are ignored rather than applied.

## 7. Dashboard control specification

| Setting | Dashboard control | Values / visibility |
|---|---|---|
| Style | visual-card dropdown | 13 canonical style ids |
| Font | dropdown | six canonical font ids |
| Weight preset | dropdown | eight named ids; set `weight` consistently |
| Size | slider/input | 24-320, default 65 |
| Width | slider/input | 0.55-1.50, default 1 |
| Height | slider/input | 1-3, default 1 |
| Position | segmented control | top/center/bottom; custom uses normalized X/Y |
| Custom X/Y | normalized sliders/inputs | 0-1; show only for custom position |
| Layout | segmented control | five layout ids |
| Line spacing | slider/input | 0.5-2; show for non-inline |
| Minute offset | slider/input | -1 to 1; show only for `offsetStack` |
| Single/split color | segmented control | split slots visible only for `split` |
| Base/hours/minutes/date/colon color | color picker | opaque ARGB/CSS colors; date and split slots conditional |
| Show colon | switch | show only for `inline`; effective in current renderer only with split color |
| Shadow/glow/stroke | switches | stroke width visible only when stroke is enabled |
| Stroke width | slider/input | 0.5-20, default 2 |
| 12/24 hour, seconds | switches | independent |
| Show date | switch | date controls visible only when true |
| Date position | segmented control | above/below |
| Date size | slider/input | 0.5-2, default 1 |
| Depth enabled | switch | enabled only when both depth assets exist |
| Foreground scale/offset, blur, foreground shadow | numeric content controls | backend-authored; not exposed in current mobile editor |

## 8. Conditional and validation rules

1. A wallpaper supports depth only if its type is `depth` and both background and foreground URLs are non-empty.
2. Non-inline layouts render two rows and never render a colon. `lineSpacing` is ignored for inline.
3. `minuteOffsetX` affects only the minute row in `offsetStack`.
4. Split mode uses hours/minutes colors and, for inline, the colon color. Missing split colors fall back to base `color`.
5. `colonColorCustom` is valid only with `colorMode=split`, `timeLayout=inline`, and `colonColor=custom`.
6. Date position/color/scale are relevant only when `showDate=true`.
7. `customX` and `customY` must be supplied together. If either is missing, mobile uses the anchor position.
8. Clamp numeric inputs to the ranges in section 3. Use CSS `#RRGGBB` or `#RRGGBBAA` for API colors; alpha is the final two bytes.
9. Do not send `null` for required enum fields. Unknown enum values must be rejected by the Dashboard or mapped to the documented fallback before publishing.

## 9. Style selection behavior

Selecting a style in the mobile editor seeds: style, font, named weight, time layout, horizontal scale, color mode, stroke toggle, stroke width, and line spacing. It clears `remoteStyle` and `remoteFont`. It preserves size, opacity, base colors, shadow/glow, date settings, position, rotation, stretch, and date scale. The Dashboard should treat style presets as explicit defaults, not as a runtime style binding.

## 10. Persistence, rendering, and compatibility

Local user overrides are JSON-encoded flat `ClockConfigModel` objects in Hive box `clock_config`, key `wallpaper:<wallpaperId>`. Depth user toggle is in Hive box `depth_config`, keyed by raw wallpaper id, and contains only `enabled` and `hasForegroundMask`. Clock precedence is user override > remote default > built-in default.

The final Android live wallpaper receives clock JSON and depth JSON over `com.backgrounds.trend4k` MethodChannels. The render order is background plate, clock/date, foreground subject. Foreground is drawn last, so the clock is behind the subject.

Known parity warnings the Dashboard must preserve or explicitly communicate:

- Single-color inline `showColon=false` is ineffective in both current renderers; the non-split inline path always includes `:`.
- `ClockColonColor.custom` exists in model/native serialization but is absent from the normal current UI option list.
- `fontWeightPreset` is not effective while remote authorship markers remain set; raw remote `weight` wins.
- Clock `depth` is stored/mapped but not used by either renderer.
- Foreground `shadowStrength` is preview-supported but ignored by the Android compositor.
- Android background blur is unavailable below API 31.
- Native glow is an approximation of Flutter's two-shadow glow.
- Current remote ingestion cannot provide every editor option; extending the backend payload alone is insufficient until the mobile mapper/native parsing are updated.

## 11. Implementation references

Primary source locations:

- `lib/features/clock/domain/entities/clock_config_entity.dart`
- `lib/features/clock/domain/entities/clock_style_preset.dart`
- `lib/features/clock/data/models/remote_clock_config_mapper.dart`
- `lib/features/clock/data/models/clock_config_model.dart`
- `lib/features/clock/data/repositories/clock_repository_impl.dart`
- `lib/features/customize/presentation/widgets/clock_settings_panel.dart`
- `lib/features/depth/presentation/widgets/depth_layer_stack.dart`
- `lib/features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart`
- `android/app/src/main/kotlin/com/backgrounds/trend4k/ClockConfig.kt`
- `android/app/src/main/kotlin/com/backgrounds/trend4k/ClockRenderer.kt`
- `android/app/src/main/kotlin/com/backgrounds/trend4k/DepthCompositor.kt`

See [`DEPTH_WALLPAPER_FEATURE_SPEC.md`](./DEPTH_WALLPAPER_FEATURE_SPEC.md) for the full style catalog, 39-color catalog, field-by-field model, renderer matrix, and code map.
