# Design Rendering Contract

**Status:** IMPLEMENTED. Phase 0 discovery findings are retained below as the
record of what was wrong and why; §13 onward documents the implemented
contract.
**Date:** 2026-09-20 (discovery and implementation)
**Scope:** How dashboard-authored design reaches the mobile renderers for
STATIC, LIVE/VIDEO and DEPTH wallpapers.

All API facts below were captured from the live production API on the date
above, not inferred from documentation or from the dashboard source. Field
lists are machine-extracted from actual responses.

---

## 0. Executive summary

The rendering pipeline is **structurally intact end to end**. The domain
entity, the Flutter painter, the Dart→native serializer and the Kotlin
renderer all already support the fields the dashboard authors.

There is exactly one break, and it is narrow:

> `RemoteClockConfigMapper.fromJson` reads **15 of 48** authored clock fields
> and drops the other **33**. It is one schema generation behind the API it
> parses.

Separately, the entire newer `studio` object — the generation the dashboard
now writes for STATIC wallpapers — has **zero references anywhere in the Dart
codebase**.

Consequence, stated plainly:

| Wallpaper generation | Count in feed | What mobile renders today |
|---|---|---|
| Legacy `clockConfig` (depth) | 2 | Clock renders, but wrong size / layout / colour |
| New `studio` (5 static, 1 depth) | 6 | **No design at all** — `studio` is never read |
| No design | 31 | Correct (nothing to render) |

The Bunny case in the brief is the first row. The five `standard` studio
wallpapers are the second row and are a strictly larger problem that the
Bunny screenshots do not show.

---

## 1. Current API design schema

### 1.1 Where design lives

Design is carried on **both** the list endpoint and the detail endpoint, so
rendering a design never requires a detail fetch:

- `GET /api/v1/public/wallpapers?limit=60` — list items already include
  `studio`, `clockConfig`, `depthConfig`.
- `GET /api/v1/public/wallpapers/{slug}` — same fields, plus `assets`,
  `video`, `description`, `studio.styledPreviewUrl`.

### 1.2 Two coexisting generations

Two clock containers exist:

- **Legacy:** top-level `clockConfig` — 46 fields, carries `schemaVersion: 1`.
- **Current:** `studio.clock` — 47 fields, **no** `schemaVersion`.

They are a near-perfect superset relationship:

- 45 fields shared, identical names and value shapes.
- `studio.clock` adds `hourFormat`, `separatorBlink`.
- `clockConfig` adds `schemaVersion`.

**Precedence rule (verified across all 38 feed items):** the clock is in
`studio.clock` when that is non-null, otherwise in `clockConfig`. No wallpaper
carries a clock in both.

The one wallpaper carrying both containers (`chatgpt-image-14-...`, depth) has
`studio.clock == null` and its real clock in legacy `clockConfig` — while
`studio` still supplies `scene`, `dateWidget` and `styledPreviewUrl`. So
`studio` being present does **not** imply `studio.clock` is populated, and a
correct reader must not treat "has studio" as "ignore clockConfig".

### 1.3 The `studio` object

```
studio
├── scene            — full-frame image treatment (see 1.4)
├── clock            — 47 fields, or null (see 1.2)
├── dateWidget       — independent date element (see 1.5)
├── widgets[]        — extra elements (see 1.6)
├── behavior         — apply/entrance policy (see 1.7)
└── styledPreviewUrl — server-rendered composite WebP, or null
```

### 1.4 `studio.scene`

Photographic treatment applied to the whole wallpaper:

`brightness, contrast, saturation, warmth, exposure, sharpen, blur`
(scalars, 0 = identity), plus nested:

- `vignette {amount, softness}`
- `grain {amount, size}`
- `gradientOverlay {enabled, from, to, angleDeg, opacity, blendMode}`
- `tint {enabled, color, opacity, blendMode}`
- `duotone {enabled, shadow, highlight}`

Observed non-identity in the wild: `chatgpt-image-14-...` uses
`brightness: -0.1`, `vignette.amount: 0.35`.

**Nothing in the app parses or applies any of this.**

### 1.5 `studio.dateWidget`

A date element **independent of** the clock's own nested `clock.date`:

`enabled, format (short|medium|long), pattern, locale, position, customX,
customY, color, scale, font, weight, uppercase`

This is a second, separately-positioned date. The app models only the
clock-attached `date` (above/below the time), so a `dateWidget` at its own
`customX/customY` has no representation at all.

### 1.6 `studio.widgets[]`

Array, usually empty. **One populated instance found** (`porshe-ob91x0`):

```json
{"kind":"batteryRing","anchor":"top","customX":0.8,"customY":0.13,
 "rotation":0,"color":"#FFFFFFFF","scale":1.1,"showPercentage":true}
```

**This directly answers the brief's open question about temperature/weather.**
The only widget kind observed in production is `batteryRing` — battery level,
which is a local device reading. **No weather or temperature widget was found
in any of the 38 wallpapers.** On this evidence there is no basis for adding a
weather API or location permissions. `batteryRing` needs only `BatteryManager`,
no permission at all.

`kind` is an open vocabulary, so an unknown kind must be skipped silently
rather than treated as an error.

### 1.7 `studio.behavior`

`{applyTarget, clockEntrance, clockEntranceMs}` — observed uniformly as
`{"ask", "none", 600}`.

`applyTarget: "ask"` is the server-side expression of the brief's
**"With Design" vs "Wallpaper Only"** requirement. The field already exists;
the app never reads it.

### 1.8 `depthConfig`

`{foregroundScale, foregroundOffsetX, foregroundOffsetY, blurRadius,
shadowStrength, parallaxStrength}` — present only on `depth` wallpapers.
This one **is** parsed today.

---

## 2. Fields currently parsed by mobile

Single parse site: `WallpaperModel.toEntity()`
(`lib/features/explore/data/models/wallpaper_model.dart:207`), which calls
`RemoteClockConfigMapper.fromJson(clockConfig)`.

The mapper reads **15** fields:

`color, customX, customY, date, depth, enabled, font, opacity, position,
rotation, scale, schemaVersion, shadow, style, weight`

`depthConfig` is parsed separately and correctly.

`studio` — in any form — is **not read**. Verified: `grep -rn "studio" lib/`
returns zero matches.

---

## 3. Fields currently ignored / dropped

**33 of 48** authored clock fields are dropped. They split into two groups
that need very different amounts of work.

### 3.1 Dropped, but the entity ALREADY has the field (18)

These require **only mapper lines**. No model change, no serializer change, no
Kotlin change — the rest of the chain already carries and renders them.

`colonColor, colonColorCustom, colorMode, dateScale, fontWeightPreset,
horizontalScale, hoursColor, lineSpacing, minuteOffsetX, minutesColor,
showColon, showGlow, showSeconds, showStroke, sizePx, stretchY, strokeWidth,
timeLayout`

Every field the Bunny regression depends on is in this group.

Why this gap exists: these fields were added to the entity for the in-app
Customize editor (since deleted). They were wired entity → model → native →
Kotlin, but never wired API → entity, because at the time the backend did not
author them. The backend now does.

This is visible in the source as stale documentation: `ClockConfigEntity`
still describes `stretchY`, `dateScale`, `fontWeightPreset` and
`horizontalScale` as *"User-only (no backend counterpart)"*, and
`ClockConfig.kt` repeats the claim. **That is no longer true** — the API
authors all four.

### 3.2 Dropped, and the entity has NO field (15)

These need a new field plumbed through five layers (entity → model →
`fromEntity`/`toEntity` → JSON → Kotlin → renderer):

`blur, fadeAmount, fadeDirection, fillOpacity, gradientAngleDeg, gradientFrom,
gradientTo, hourFormat, hoursFont, is24Hour*, minutesFont, separatorBlink,
showAmPm, strokeColor, strokeOrder`

\* `is24Hour` exists on the entity but is documented as a *user preference*
with no backend counterpart. The API now authors it. Whether authored intent
or user/locale preference wins is a **product decision, not a plumbing
decision** — flagged, not assumed.

### 3.3 Dropped wholesale

`studio.scene` (all ~20 values), `studio.dateWidget` (all 13),
`studio.widgets[]`, `studio.behavior`, `studio.styledPreviewUrl`.

---

## 4. Fields interpreted INCORRECTLY

These are worse than the drops: the mapper reads the field and then produces a
wrong value. Two are the direct cause of the Bunny regression.

### 4.1 `sizePx` is discarded and recomputed — the size regression

`remote_clock_config_mapper.dart:55`

```dart
sizePx: (baseSizePx * scale).clamp(24.0, 120.0),   // baseSizePx = 76
```

The authored `sizePx` is ignored entirely; size is re-derived from `scale`.

| Wallpaper | authored `sizePx` | authored `scale` | mapper yields |
|---|---|---|---|
| bunny | **208** | 1.0 | **76** |
| chatgpt-image-14 | **183** | 0.9 | **68.4** |
| red-earth | 65 | 1.3 | 98.8 |
| porshe | 65 | 1.1 | 83.6 |

Bunny is authored at 208px and rendered at 76px — **63% too small**. The
`.clamp(24, 120)` makes the authored 208 unreachable even if it were read.

### 4.2 `font: "Oswald"` → Inter — the typeface regression

`remote_clock_config_mapper.dart:135-143` matches only serif and mono
keywords; everything else falls back to `ClockFont.inter`.

`ClockFont.oswald` **exists in the enum** and the font is bundled. The mapper
has no branch that can return it. Bunny authors `Oswald`; mobile renders Inter.

### 4.3 `style: "monument"` → modern

`_styleFrom` maps 8 legacy ids to 4 styles. `ClockStyle.monument` exists in the
enum, but `monument` is not in the switch, so it hits the `_ => modern`
default. The raw string survives in `remoteStyle`, unused by the renderers.

### 4.4 `position: "custom"` is lossily downgraded

`_positionFrom` collapses `custom` to the nearest of top/center/bottom by
`customY`. Harmless in isolation — both renderers prefer `customX/customY`
when `hasCustomPosition` — but it means `position` and `customX/Y` can
disagree, and any code reading `position` alone gets the wrong answer.

### 4.5 Wrong defaults when a sub-object is absent

`showShadow`, `showDate` default to **true** when `shadow`/`date` are missing.
Absent should mean off, not on. A wallpaper with no authored date gets a date.

### 4.6 Net effect on Bunny

| Property | Dashboard authored | Mobile renders | Cause |
|---|---|---|---|
| Layout | `stackedCompact` (two rows) | inline (one row) | §3.1 dropped |
| Minute colour | `#E65100` orange | white | §3.1 `colorMode`/`minutesColor` dropped |
| Size | 208px | 76px | §4.1 recomputed |
| Font | Oswald | Inter | §4.2 unreachable |
| Style | monument | modern | §4.3 unmapped |
| Position | 0.348, 0.274 | honoured | correct |

This fully accounts for the reported symptom — stacked orange/white "02"/"56"
authored, inline white "2:58" rendered — with no unexplained residue. The
position was never the problem; five independent property losses were.

---

## 5. Dashboard vs mobile coordinate systems

Both Flutter and Kotlin treat `customX`/`customY` as normalized 0..1 fractions
of the render surface, anchored at the **centre** of the clock block:

- `clock_painter.dart:254` — `width * x` is the block's horizontal centre.
- `clock_painter.dart:262-265` — `(height * y) - blockHeight / 2`.
- `ClockRenderer.kt:382-396` — same convention.

So Flutter and native agree with each other. **Whether the dashboard uses the
same centre-anchored convention is NOT yet verified.** Bunny's `customY: 0.274`
rendering high on the screen is consistent with centre-anchoring, but
consistent-with is not proof. This must be confirmed against the dashboard
before any coordinate code is written — a top-left convention would introduce
a half-block offset that grows with font size, which would be invisible at
76px and obvious at 208px.

The genuine coordinate hazard is a different one, and it is already solved:
the render surface is not the screen. `LiveWallpaperService.visibleViewport()`
returns the screen-sized rect centred inside a possibly-wider launcher
parallax surface, and the clock is drawn inside
`canvas.translate(viewport.left, viewport.top)`. **This must not regress** —
per the brief, and because a normalized 0..1 coordinate resolved against the
full 2340-wide surface instead of the 1080-wide viewport lands roughly
half a screen off.

---

## 6. Flutter preview vs native Android rendering

| | Flutter (`ClockPainter`) | Native (`ClockRenderer.kt`) |
|---|---|---|
| Source of config | `WallpaperEntity.remoteClockConfig` | `ClockConfig.fromJson` of serialized entity |
| Field coverage | full entity | full entity |
| Locale | `en_US` pinned | `Locale.US` pinned |
| Direction | `TextDirection.ltr` hardcoded | n/a |
| Surface | widget box | wallpaper surface via `visibleViewport()` |

Both renderers consume the **same entity** and support the same fields, so
once the mapper is fixed they should agree. The divergence risk is not in the
renderers; it is that they are fed by two different paths — Details reads the
entity directly, while apply goes entity → `ClockConfigModel.toJson` → Kotlin.
That serializer round-trip is complete (verified field by field), so it is not
currently a source of loss.

Locale pinning in both is correct and must be preserved.

---

## 7. Static / Live / Depth path differences

Routing lives in `ApplyWallpaperRepositoryImpl.apply()`:

- `type == live` → `_applyVideo(...)`, always live engine.
- otherwise → `isLiveApply(clockConfig:, depthConfig:)` decides.

`WallpaperEntity.isLiveApply` (`wallpaper_entity.dart:183-189`):

```dart
type == WallpaperType.live || clockConfig != null || (depthConfig?.enabled ?? false)
```

**This is the key architectural finding for STATIC design support.** A
`standard` wallpaper that carries a clock is *already* routed to the live
wallpaper engine rather than `setBitmap`. The mechanism the five `standard`
studio wallpapers need therefore already exists and is already correct — it
simply never triggers, because `clockConfig` is null for them, because
`studio.clock` is never parsed.

| Type | Engine | Design today | Design once parsed |
|---|---|---|---|
| STATIC, no design | `setBitmap` | n/a | unchanged |
| STATIC + studio.clock | `setBitmap` (wrong) | **none** | live engine, via existing `isLiveApply` |
| LIVE / video | `VideoWallpaperService` + `GLVideoClockCompositor` | clock only | + scene/widgets |
| DEPTH | `LiveWallpaperService` + `DepthCompositor` | clock, partial | full |

Note the STATIC row is a live-wallpaper trade-off, not a free win: applying a
static wallpaper through the live engine costs a persistent service and
battery where `setBitmap` costs nothing. Whether every designed static
wallpaper should become a live wallpaper — or only when the design is actually
dynamic (a clock ticks; a `scene` filter does not) — is a product decision.
A static `scene`-only design could be baked into the bitmap at apply time and
stay a true static wallpaper. **Flagged for decision before implementation.**

---

## 8. Mapping table: API → Dart → Flutter → native → Kotlin

> **Note:** this table records the state *found during discovery*. Every row
> marked **MAPPER** or **WRONG** is now **fixed** — see §13 and the test file
> `test/remote_clock_config_mapper_contract_test.dart`, which asserts each one.
> Rows marked **PLUMB** and **NONE** remain unimplemented; §21 lists them.

Status legend: **OK** end-to-end · **MAPPER** dropped, entity ready (mapper
lines only) · **PLUMB** dropped, needs new field through 5 layers · **WRONG**
read but corrupted · **NONE** no representation anywhere.

### 8.1 Clock

| API field | Dart entity | Flutter | Native JSON | Kotlin | Status |
|---|---|---|---|---|---|
| `enabled` | `enabled` | yes | yes | yes | **OK** |
| `color` | `color` | yes | yes | yes | **OK** |
| `opacity` | `opacity` | yes | yes | yes | **OK** |
| `customX` / `customY` | same | yes | yes | yes | **OK** |
| `rotation` | `rotation` | yes | yes | yes | **OK** |
| `weight` | `weight` | yes | yes | yes | **OK** |
| `depth` | `depth` | yes | yes | yes | **OK** |
| `shadow.*` | `showShadow`/`shadowStrength` | yes | yes | yes | **WRONG** (§4.5 default) |
| `date.*` | `showDate`/`datePosition`/`dateColor` | yes | yes | yes | **WRONG** (§4.5 default) |
| `position` | `position` | yes | yes | yes | **WRONG** (§4.4 lossy) |
| `sizePx` | `sizePx` | yes | yes | yes | **WRONG** (§4.1 recomputed) |
| `font` | `font` | yes | yes | yes | **WRONG** (§4.2 Oswald unreachable) |
| `style` | `style` | yes | yes | yes | **WRONG** (§4.3 monument unmapped) |
| `timeLayout` | `timeLayout` | yes | yes | yes | **MAPPER** |
| `colorMode` | `colorMode` | yes | yes | yes | **MAPPER** |
| `hoursColor` | `hoursColor` | yes | yes | yes | **MAPPER** |
| `minutesColor` | `minutesColor` | yes | yes | yes | **MAPPER** |
| `colonColor` / `colonColorCustom` | same | yes | yes | yes | **MAPPER** |
| `showColon` | `showColon` | yes | yes | yes | **MAPPER** |
| `lineSpacing` | `lineSpacing` | yes | yes | yes | **MAPPER** |
| `minuteOffsetX` | `minuteOffsetX` | yes | yes | yes | **MAPPER** |
| `stretchY` | `stretchY` | yes | yes | yes | **MAPPER** |
| `horizontalScale` | `horizontalScale` | yes | yes | yes | **MAPPER** |
| `fontWeightPreset` | `fontWeightPreset` | yes | yes | yes | **MAPPER** |
| `dateScale` | `dateScale` | yes | yes | yes | **MAPPER** |
| `strokeWidth` | `strokeWidth` | yes | yes | yes | **MAPPER** |
| `showStroke` / `showGlow` / `showSeconds` | same | yes | yes | yes | **MAPPER** |
| `is24Hour` | `is24Hour` | yes | yes | yes | **MAPPER** + policy (§3.2) |
| `showAmPm` | — | — | — | — | **PLUMB** |
| `hourFormat` | — | — | — | — | **PLUMB** |
| `separatorBlink` | — | — | — | — | **PLUMB** |
| `strokeColor` / `strokeOrder` | — | — | — | — | **PLUMB** |
| `fillOpacity` | — | — | — | — | **PLUMB** |
| `blur` | — | — | — | — | **PLUMB** |
| `fadeAmount` / `fadeDirection` | — | — | — | — | **PLUMB** |
| `gradientFrom` / `gradientTo` / `gradientAngleDeg` | — | — | — | — | **PLUMB** |
| `hoursFont` / `minutesFont` | — | — | — | — | **PLUMB** |

### 8.2 Everything else

| API | Status |
|---|---|
| `depthConfig.*` | **OK** |
| `studio.scene.*` | **NONE** |
| `studio.dateWidget.*` | **NONE** |
| `studio.widgets[]` (`batteryRing`) | **NONE** |
| `studio.behavior.applyTarget` | **NONE** — maps to With Design / Wallpaper Only |
| `studio.styledPreviewUrl` | **NONE** — see §9 |

---

## 9. `styledPreviewUrl` — a decision worth making early

The server already renders a composite WebP of the finished design
(populated on `red-earth`, `chatgpt-image-14-...`; null on others).

This is a strong fit for the brief's constraint *"do NOT render full design
compositions inside every Home card."* Grid cards can show the server
composite — one image decode, no clock engine, guaranteed-faithful — while
only Details and Apply run live rendering.

Caveats: it is null for some designed wallpapers, so a fallback is required;
and it is a **static** render, so a live clock must not use it as its final
frame. Treat it as a preview/thumbnail source, never as the applied output.

---

## 10. Recommended sequencing

1. **Fix the mapper's 18 entity-ready fields + 5 misinterpretations.**
   One file. Fixes the entire Bunny regression class and every legacy-schema
   wallpaper. Highest value per unit of risk by a wide margin.
2. **Parse `studio.clock` with the §1.2 precedence rule.** Unlocks design on
   the 5 `standard` wallpapers that currently render none.
3. **Decide the STATIC-design apply policy** (§7) before wiring apply.
4. **`studio.behavior.applyTarget`** → the With Design / Wallpaper Only choice.
5. **`studio.scene`** — new render stage, both renderers.
6. **`studio.dateWidget`, `widgets[]` (batteryRing)** — new elements.
7. **The 15 PLUMB clock fields** — widest blast radius, lowest marginal gain.

## 11. Open questions requiring a decision

1. **Dashboard anchor convention** — centre or top-left? (§5) Must be
   confirmed, not assumed.
2. **STATIC + design → live engine?** Battery/service cost vs fidelity (§7).
3. **`is24Hour` / `hourFormat`** — authored intent or user/device preference?
4. **`scale` vs `sizePx`** — both authored, currently one derives the other.
   Proposed: `sizePx` is truth, `scale` is a multiplier on it, and the
   `.clamp(24, 120)` ceiling is raised to admit the authored 208.
5. **`widgets[]` scope** — `batteryRing` only, or a general widget framework?
   No weather/temperature widget exists in production data today.

---

## 12. Verification status (discovery phase)

- API schema: **verified** against live production, 38 feed items + detail
  fetches, field lists machine-extracted.
- Dart/Kotlin coverage: **verified** by reading source.
- Bunny root cause: **verified** — five specific losses fully account for the
  reported symptom.
- Dashboard anchor convention: resolved during implementation — see §14.
- On-device rendering: performed during implementation — see §20.

---

# PART II — THE IMPLEMENTED CONTRACT

## 13. Clock contract (implemented)

### 13.1 One parser, both generations

`RemoteClockConfigMapper.fromJson` reads either container. They share 45
identically-shaped fields, so the caller — `WallpaperModel.toEntity` via
`StudioDesignMapper` — decides which to hand over; the parser does not need to
know the generation.

**Precedence:** `studio.clock` when non-null, otherwise the legacy top-level
`clockConfig`. The two are NOT mutually exclusive: a wallpaper can carry
`studio` with a null `clock` while its real clock sits in `clockConfig`
(`chatgpt-image-14-…` does exactly this in production). Treating "has studio"
as "ignore clockConfig" would lose that wallpaper's clock entirely.

### 13.2 Size precedence

```
explicit authored sizePx  >  legacy derived (76 × scale)  >  entity default
```

An explicit `sizePx` wins outright and `scale` is **not** applied on top of it
— doing so would double-count (208 × 1.3). `scale` remains carried on the
entity and is still the sole size input for legacy configs that never authored
a `sizePx`, so old wallpapers render exactly as before.

The legacy 24–120 clamp is gone. It was an artifact of the derived formula
(`76 × scale`, scale ≤ 3.0), never a renderer limit — nothing in the entity,
the model, `ClockConfig.kt`, `ClockPainter` or `ClockRenderer.kt` imposes a
ceiling. The bound is now **24–320**, matching the dashboard's own documented
range for this field (`DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md` §3), so a corrupt
value still cannot allocate an absurd text layout.

A `sizePx` of 0, negative, non-finite or non-numeric falls back to the derived
size rather than producing an invisible clock.

### 13.3 Vocabulary

- **Style:** every `ClockStyle` the renderers implement is reachable by its own
  id (`monument`, `stencil`, `soft`, …). Legacy aliases (`thin`, `classic`,
  `solid`, `bold`, `rounded`, `outlined`) still resolve as before.
- **Font:** the bundled display faces are reachable by name — `Oswald`,
  `ArchivoBlack`, `Anton`, including spacing/hyphen variants. Serif and mono
  keep matching by keyword. Unknown families fall back to Inter with the raw
  name preserved in `remoteFont`.
- **Layout / colour mode / colon colour / weight preset:** every enum value
  round-trips from its wire spelling; unknown values fall back to the
  documented default.

### 13.4 Corrected defaults

An absent or unreadable `shadow` / `date` sub-object now means **OFF**, not on.
The previous `true` default drew a shadow and a date on wallpapers that
authored neither. Every production clock authors both objects explicitly (all
with `date.enabled: false`), so this path is only reachable on malformed data —
where inventing a date would be strictly wrong.

### 13.5 Defensive reading

No cast can throw. Every string field is read through a type-checked reader, so
a backend that sends a number where a colour string was expected yields "not
authored" rather than a crash. NaN and Infinity never reach the renderers.
Unknown fields are ignored outright.

---

## 14. Coordinate anchor — EVIDENCE AND DECISION

**Convention: centre-anchored. No conversion is applied anywhere.**

Evidence, in order of authority:

1. **Dashboard documentation** (`docs/DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md`
   §3), verbatim:

   | `customX` | 0 | 1 | null | normalized clock **center** X |
   | `customY` | 0 | 1 | null | normalized clock **center** Y |

2. **Both mobile renderers already centre-anchor.** `ClockPainter._centerX`
   returns `width * x`; `_positionTop` returns `(height * y) - blockHeight / 2`;
   `ClockRenderer.kt:382-396` mirrors both.

3. **The backend's own composed render agrees.** The `bunny` PREVIEW asset —
   the dashboard's flattened output — places the clock where the mobile overlay
   independently draws it from the same `customX/customY`.

Dashboard and mobile therefore already agree, so per the brief the existing
anchor behaviour was left intact. Tests pin this down (`coordinate anchor
(Stage 9 evidence)`) so a future "fix" cannot quietly introduce an offset.

---

## 15. The `studio` object (implemented)

Typed end to end — no `Map<String, dynamic>` reaches the UI.

- `StudioDesign` — the canonical design: clock, scene, dateWidget, widgets,
  applyTarget, clockEntrance, styledPreviewUrl, unsupportedWidgetKinds.
- `StudioScene` — every scalar plus `vignette`, `grain`, `gradientOverlay`,
  `tint`, `duotone`. Carries `hasVisibleEffect`; a scene entirely at identity
  values is collapsed to null at parse time, so it cannot make an undesigned
  wallpaper count as designed (nearly the whole catalogue ships an all-zero
  scene).
- `StudioDateWidget` — the independent date element, distinct from the clock's
  own nested `date`.
- `StudioWidget` — a sealed type. `StudioBatteryRing` is the only implemented
  kind, because it is the only kind production authors.
- `StudioApplyTarget` / `StudioClockEntrance` — typed enums with safe
  fallbacks.

**Forward compatibility:** an unknown widget `kind` is skipped and recorded in
`unsupportedWidgetKinds`, leaving the rest of the design renderable. Malformed
design data of any shape returns normally rather than throwing.

---

## 16. `hasDesign` — the canonical decision

One answer, on `WallpaperEntity`, re-derived by no screen:

```dart
bool get hasDesign => design?.hasDesign ?? false;
```

A wallpaper has a design when its parsed configuration carries meaningful
authored content: an **enabled** clock, a scene with a visible effect, an
enabled date element, or at least one supported widget. A clock authored
`enabled: false` does not count — that is a wallpaper deliberately shipped bare.

**Deliberately independent of media type.** STATIC / LIVE / DEPTH describe the
media and how it is rendered; DESIGN is orthogonal. A static wallpaper can carry
a full design; a depth wallpaper can carry none.

Derived from it:

- `designRenderMode` → `none` / `static_` / `dynamic_`
- `hasDynamicDesign`, `hasStaticOnlyDesign`
- `previewHasBakedDesign`, `shouldRenderDesignOverlay` (see §18)

---

## 17. Dynamic vs static classification

| Element | Classification | Why |
|---|---|---|
| Enabled clock | **dynamic** | displays the current time |
| `batteryRing` | **dynamic** | reflects live battery state |
| Scene treatment | static | a colour grade does not change |
| Date element | static | changes at midnight, not continuously |

Consequence for apply:

| Media + design | Engine |
|---|---|
| Static, no design | `setBitmap` (unchanged) |
| Static + static-only design | `setBitmap` — **no live service** |
| Static + dynamic design | live engine, via the existing `isLiveApply` |
| Video / live | live/video renderer |
| Depth | depth renderer |

A static wallpaper is never promoted to a persistent live wallpaper merely for
carrying a colour grade. This routing already existed in
`WallpaperEntity.isLiveApply` and was preserved rather than rebuilt — a
scene-only design produces no clock config, so it stays on the static path by
construction.

**Static composition of a `scene` is NOT implemented.** Baking brightness /
contrast / vignette / grain / duotone into the bitmap would require a second
image-processing renderer that does not exist today, and a second renderer is
exactly how visual drift between preview and applied output begins. Per the
brief's "correctness first, optimization second", this is documented as
unimplemented rather than approximated. No production wallpaper currently ships
a scene-only design, so nothing regresses.

---

## 18. Details rendering

`DesignOverlay` is the one Flutter-side composition of an authored design, used
by Details for every media type so a design cannot look different depending on
the screen or wallpaper type. It renders the **same `StudioDesign`** the apply
pipeline serializes to native, is non-interactive (`IgnorePointer`), and paints
above the media but below the UI chrome.

**Critical rule — draw only what the media lacks.** Whether the overlay draws
depends on WHICH ASSET is painted, not on the wallpaper's type, and the two
genuinely differ. Both cases were verified against production:

| Case | Asset Details paints | Baked? | Overlay |
|---|---|---|---|
| DEPTH with both layers | backend's composed THUMBNAIL/PREVIEW (no flattened asset exists) | **yes** | skipped |
| STATIC with a design | the plain photograph | no | **drawn** |
| LIVE/video | the raw clip | no | **drawn** |

The `bunny` PREVIEW contains the clock while its BACKGROUND plate is bare;
`porshe` carries a full authored design yet its PREVIEW has none of it. Drawing
unconditionally produced a visible double clock on-device; the rule above fixed
it. Expressed once, as `WallpaperEntity.shouldRenderDesignOverlay`.

Home/feed cards are unchanged — they keep showing their thumbnail, so no live
clock ticks behind a grid tile.

---

## 19. Apply behaviour

`studio.behavior.applyTarget` is honoured:

| Value | Behaviour |
|---|---|
| `ask` (the only value in production) | show the **With Design / Wallpaper Only** selector |
| `withDesign` | apply the design, no prompt |
| `wallpaperOnly` | apply the bare media, no prompt |
| unknown / absent | fall back to `ask` — never silently override the user |

The selector is a compact segmented row on the **existing** sheet — no second
screen — shown only when the wallpaper has a design AND the dashboard asked.
Home / Lock / Both and every other existing control are untouched.

The choice is real, not cosmetic: picking "Wallpaper Only" suppresses the clock
config reaching the apply call, so `isLiveApply` routes the wallpaper back down
the ordinary static path. Verified on-device (§20).

A wallpaper with **no** parsed design is never affected — whatever config the
caller passed is applied exactly as before, which preserves every legacy call
site.

---

## 20. On-device verification

Performed on the Android emulator `emulator-5554` (Android 17, API 37) with the
**release** APK. **No physical device was connected, so no physical-device
verification is claimed.**

| Check | Result |
|---|---|
| Bunny Details (depth, legacy schema) | authored design renders once — stacked `10`/`12`, white hours, `#E65100` minutes, Oswald, correct size and position; no double clock |
| Porshe Details (static, studio schema) | clock `3:57` at authored 0.3/0.16 **and** battery ring showing real level at 0.8/0.13 |
| Battery ring | reads the emulator's actual battery via `BatteryManager`; no permission requested |
| Apply sheet, designed wallpaper | With Design / Wallpaper Only shown, With Design pre-selected, fits with no scrolling |
| Wallpaper Only → static | sheet switches to Home/Lock/Both + "Apply Wallpaper" |
| Wallpaper Only applied | bare photo on home screen, no design, single page, no seams; `dumpsys wallpaper` reports `ImageWallpaper` — **no live service spawned** |
| With Design → live picker | Android's picker renders `LiveWallpaperService` with the **native** Kotlin clock drawn at the authored position |
| Home/feed cards | plain thumbnails, no per-card design composition |

Not completed on-device: confirming the live wallpaper after the system
picker's final "Set wallpaper" confirmation, because an interstitial ad
repeatedly intercepted the scripted taps at that step. The picker's own preview
— which is `LiveWallpaperService` rendering — was captured and is correct.

---

## 21. Remaining unsupported backend fields

Parsed into the typed model but **not yet rendered**: `studio.scene.*` (all),
`clockEntrance` / `clockEntranceMs`, `styledPreviewUrl`.
(`studio.dateWidget` was rendered in a later pass - see §24.)

Not modelled at all (15 clock fields needing new plumbing through five layers):
`showAmPm`, `hourFormat`, `separatorBlink`, `strokeColor`, `strokeOrder`,
`fillOpacity`, `blur`, `fadeAmount`, `fadeDirection`, `gradientFrom`,
`gradientTo`, `gradientAngleDeg`, `hoursFont`, `minutesFont`.
(All 15 were audited and classified in a later pass - see §26. `showAmPm` and
`is24Hour` are now implemented.)

`is24Hour` was left as a user preference in this pass; a later pass resolved it
against the dashboard contract and made the authored value authoritative - see
§27.

No weather or temperature feature exists, and none was invented — no such
widget appears anywhere in production data.

---

## 22. Remaining risks

1. **`scene` is parsed but not rendered.** A wallpaper authored with a heavy
   colour grade will render without it. Only `chatgpt-image-14-…` currently
   ships a non-identity scene (brightness −0.1, vignette 0.35), so the visible
   impact today is small — but it will grow as the dashboard is used.
2. **`dateWidget` is parsed but not rendered.** Two production wallpapers
   enable it. The clock's own nested date still renders normally.
3. **Depth Details shows the backend's composed image**, so a depth design is
   only as current as that render — its baked clock shows the time the asset was
   generated, not the live time. This is pre-existing behaviour, unchanged by
   this pass, and the applied wallpaper is live regardless.
4. **The baked/not-baked rule keys off `supportsDepth`.** If the backend later
   starts publishing flattened assets for static wallpapers too, §18's table
   must be revisited.
5. **No physical-device verification.** Emulator only.
---

# PART III — NATIVE PARITY (second implementation pass)

The first pass closed the clock contract but left elements that rendered in
Details and vanished once applied. This pass closes those.

## 23. batteryRing — native rendering

### 23.1 Architecture

| Piece | Role |
|---|---|
| `StudioWidgetConfig.kt` | Kotlin mirror of the sealed `StudioWidget` type; unknown `kind` dropped at parse time |
| `BatteryRingRenderer.kt` | THE one native ring renderer, shared by every path |
| `BatteryLevelObserver.kt` | Event-driven battery observation with explicit lifecycle |
| `StudioWidgetSerializer` (Dart) | Encodes widgets for the wire |

One renderer, not three. `LiveWallpaperService` (static-routed-to-live and
depth) composes it directly; `VideoWallpaperService` delegates to
`GLVideoClockCompositor`, which composes the same one onto the same overlay
texture as the clock. A test asserts exactly one `class BatteryRingRenderer`
exists anywhere in the Kotlin sources.

### 23.2 Property mapping

Every property below is one the production backend actually authors. Nothing
was invented.

| API | Dart model | Flutter widget | Native wire | Kotlin renderer | Status |
|---|---|---|---|---|---|
| `kind: "batteryRing"` | `StudioBatteryRing` | `BatteryRingWidget` | `"kind"` | `StudioWidgetConfig.BatteryRing` | OK |
| `customX` / `customY` | same | centre anchor | same | `width * (customX ?: 0.5f)` | OK |
| `color` (CSS `#RRGGBBAA`) | ARGB int | `Color(config.color)` | ARGB int | `config.color.toInt()` | OK |
| `scale` | `scale` | multiplies diameter + stroke | same | same | OK |
| `rotation` | `rotation` | `canvas.rotate` about centre | same | `canvas.rotate(r, cx, cy)` | OK |
| `showPercentage` | `showPercentage` | centred text | same | `drawText` centred | OK |
| `anchor` | `anchor` | carried | carried | carried | CARRIED — production only ever authors `"top"`, and `customX/customY` already fully determine placement, so nothing reads it yet |

Colours cross the boundary as **ARGB ints**, already converted from CSS byte
order by `StudioDesignMapper`. Native never re-parses a colour string, so the
two sides cannot disagree about byte order.

### 23.3 Visual parity

`BatteryRingMetrics` (Dart) and `BatteryRingRenderer.Metrics` (Kotlin) hold the
same numbers, and a test asserts both sides:

| Quantity | Value |
|---|---|
| Base diameter | 64 logical px at `scale: 1.0` |
| Base stroke | 6 logical px |
| Radius | `(diameter - stroke) / 2` |
| Track alpha | 0.25 of the authored colour |
| Start angle | 12 o'clock, clockwise (`-pi/2` rad == `-90` deg) |
| Percentage text | `diameter * 0.30`, centred on the glyph box |
| Anchor | **centre**, the already-proven convention — unchanged |

Sizes are authored in Flutter logical pixels, so native multiplies by display
density, exactly as `ClockRenderer` converts `sizePx`.

An unknown level draws the **track only**. An empty ring would read as "0%",
which would be a lie rather than an absence.

### 23.4 Battery updates

Event-driven via `ACTION_BATTERY_CHANGED`, never a timer — a poll would burn
wakeups to learn something the system volunteers. A test asserts no
`postDelayed` / `Timer(` / `scheduleAtFixedRate` appears in the observer.

- **Registered** only when the wallpaper actually draws a ring AND is visible.
- **Unregistered** on hide and on destroy, defensively (`runCatching`, since
  unregistering twice throws).
- **Redraws only on a real change**: `ACTION_BATTERY_CHANGED` also fires for
  temperature and plug events that leave the percentage alone.
- Registering for the **sticky** broadcast returns the last value immediately,
  so the first frame has a level without waiting.
- No permission. Battery level is not private data on Android.

The video path additionally folds the level into the overlay texture's cache
key — without that the ring would freeze at its first value.

### 23.5 One battery source

Found during device verification: the Details preview read
`BATTERY_PROPERTY_CAPACITY` (sysfs-backed) while the applied wallpaper read the
broadcast's `EXTRA_LEVEL`. These normally agree but are different APIs, and on
an emulator `dumpsys battery set level` overrides one and not the other — the
preview showed 100 while the system showed 37.

Both now read the **sticky broadcast**, the same source the status bar shows,
with the property API kept only as a fallback. Reading one source everywhere is
what keeps preview and applied output showing the same number.

## 24. dateWidget — implemented (production-authored)

**Evidence:** 3 of 38 production wallpapers enable it (`red-earth`, `porshe`,
`car-gt5vys`). It is authorable and published, so per the brief it is
implemented rather than reserved.

**Semantically separate from the clock's own `date`** (§7 of the brief). It
carries its own coordinates, font, scale, weight and uppercase rule, and sits
at its own position — `porshe` puts the clock at `customY: 0.16` and the date
at `0.24`. Production never enables both: every wallpaper with `dateWidget`
enabled has `clock.date.enabled: false`, so nothing double-renders.

| API | Dart | Flutter | Native | Kotlin | Status |
|---|---|---|---|---|---|
| `enabled` | same | gates render | same | gates render | OK |
| `format` (`short`/`medium`/`long`) | same | `StudioDateFormats.patternFor` | same | mirrored | OK |
| `pattern` | same | overrides `format` | same | overrides `format` | OK (always null in production) |
| `locale` | same | pinned, not device | same | pinned, not device | OK |
| `customX` / `customY` | same | centre anchor | same | centre anchor | OK |
| `color` | ARGB | same | ARGB | same | OK |
| `scale` | same | multiplies 28px base | same | same | OK |
| `font` | same | bundled families | same | asset typeface | OK |
| `weight` | same | `FontWeight` | same | bold >= 600 | OK |
| `uppercase` | same | `toUpperCase()` | same | `uppercase(locale)` | OK |
| `position` | carried | — | — | — | CARRIED — always `"custom"` in production, where `customX/Y` fully determine placement |

Classified **static**: a date changes at midnight, not continuously, so it does
not on its own justify a live wallpaper service.

## 25. scene — parsed, NOT rendered (documented gap)

**Evidence:** 5 of 6 studio wallpapers carry a scene that would visibly change
pixels — `brightness` (-0.1), `contrast` (0.1), `warmth` (0.35),
`vignette.amount` (0.35), and an enabled `gradientOverlay`. Unused in
production: saturation, exposure, sharpen, blur, grain, tint, duotone.

So it IS production-authorable and published. It is nonetheless **not
implemented in this pass**, deliberately:

Rendering it faithfully means a colour-grading pipeline (brightness/contrast/
warmth matrices, a radial vignette, a blended gradient) implemented **twice** —
once in Flutter and once in Android — and kept pixel-identical. That is exactly
the "unsafe second renderer" the brief warns about, and the failure mode is
silent visual drift between preview and applied output, which is the class of
bug this whole effort exists to remove.

Scene is therefore the **one remaining production-authored visual gap**. It is
reported honestly rather than approximated. It affects the image's grading, not
whether an element appears or disappears between preview and applied output —
both currently show the ungraded image, so they do at least agree.

## 26. The 15 previously-unmodelled clock fields

Classified against production data (7 authored clocks):

| Field | Values in production | Class | Action |
|---|---|---|---|
| `showAmPm` | **true on 4, false on 3** | **A — production-authored** | **IMPLEMENTED** |
| `is24Hour` | false on all 7 | **A — authored** (see §27) | **IMPLEMENTED** |
| `fillOpacity` | 1 on 6, **0 on `boat`** | A — authored | Deferred: `boat` is `style: outline`, whose preset already forces a near-hollow fill (0.08) in both renderers, so the authored 0 is a refinement of an already-correct look, not a missing element |
| `fadeAmount` | 0 on 5, **0.35 / 0.05** | A — authored | Deferred: a per-glyph alpha gradient needs a shader in both renderers; same second-renderer risk as `scene` |
| `fadeDirection` | `bottom` / `both` | A — authored | Deferred with `fadeAmount` (inert without it) |
| `strokeColor` | `#000000FF` / `#000000` | A — authored | Deferred: only meaningful with `showStroke`, and the single stroked wallpaper authors black, which is already the rendered stroke colour |
| `hourFormat` | `"auto"` where present | **C — dashboard metadata** | None. `"auto"` means "defer"; `is24Hour` is the operative field |
| `separatorBlink` | false on all | **E — reserved** | None. Never enabled |
| `strokeOrder` | `"behind"` on all | **E — reserved** | None. Constant; matches current behaviour |
| `blur` | 0 on all | **E — reserved** | None |
| `gradientFrom` / `gradientTo` | null on all | **E — reserved** | None. Inert without values |
| `gradientAngleDeg` | 180 on all | **E — reserved** | None. Inert without the colours |
| `hoursFont` / `minutesFont` | null on all | **E — reserved** | None. Per-segment fonts never authored |

Four fields (`fillOpacity`, `fadeAmount`, `fadeDirection`, `strokeColor`) are
authored-but-deferred. None of them makes an element appear or disappear; each
adjusts how an already-rendered clock looks, and each is reported rather than
silently dropped.

### 26.1 showAmPm

Implemented in both renderers with identical guards: skipped in 24-hour mode
(meaningless), on stacked layouts (which split hours and minutes onto separate
rows via `ClockLayoutEngine` and have no slot for a suffix), and in split-colour
mode (where `_splitTimeParts` cuts at the colon, so a " PM" suffix would land in
the minutes segment and take `minutesColor`).

All 4 production wallpapers that request it are `inline` + `single` colour — the
simple case — so the guards never fire on real data. They exist so a future
authored combination fails soft rather than mis-rendering.

## 27. is24Hour — decision and evidence

**Decision: the authored design is authoritative.** `is24Hour` now flows from
the API through the mapper into both renderers.

Evidence, weighed:

- **For (newer, authoritative):** `DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md` §1 —
  *"The current **editor** supports … 12/24-hour mode"* — and §7's editor
  controls table lists **"12/24 hour, seconds | switches"**. The dashboard
  authors it.
- **Against (older):** `DEPTH_WALLPAPER_FEATURE_SPEC.md` §522 lists 12/24-hour
  under *"User-only in current app"*.

The dashboard contract is the newer document and describes the editor directly,
so it governs. This also makes `is24Hour` consistent with `showSeconds`, which
the same table lists beside it and which the mapper already treated as authored.

Risk is low: every production wallpaper authors `false`, which is also the
previous default, so no existing wallpaper changes appearance.

## 28. Verification (second pass)

Emulator `emulator-5554` (Android 17, API 37), **release** APK.

| Check | Result |
|---|---|
| Porshe Details | clock `10:40 PM` (AM/PM now rendering), battery ring at the live level, `Sep 20` date |
| Battery set to 37 | Details ring showed **37**, arc ~37% from 12 o'clock |
| Apply With Design → picker | native `LiveWallpaperService` drew clock + ring **37** + date |
| Battery 37 → 82 while applied | native ring updated to **82** within ~4s, event-driven |
| Wallpaper Only applied | `dumpsys wallpaper` reported `ImageWallpaper` — no live service, no clock, no ring, no date |
| Full design parity | Details and applied wallpaper show the same four elements |

**PHYSICAL DEVICE NOT VERIFIED** — no physical device was connected for this
pass; only the emulator. The brief requires a physical device before declaring
native parity complete, so that requirement is **not met**.

Two defects were found *by* device verification and fixed:

1. **Battery source divergence** (§23.5) — preview and applied wallpaper read
   different APIs.
2. **The date never reached the static apply path** — it was serialized and
   passed on the video path only, so it rendered in Details and vanished once
   applied. A test now asserts every `_channel.apply*` call forwards both the
   widgets and the date.
