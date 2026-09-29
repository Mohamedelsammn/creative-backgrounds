# Creative Backgrounds — Final Production Audit

> Evidence-based release gate. No production code was modified during this audit.
> Every claim below is tagged **VERIFIED** (observed on device/artifact),
> **MEASURED** (numeric result captured), **CODE-INSPECTED** (read, not run), or
> **NOT VERIFIED** (could not be established in this environment).

---

## 1. Executive Summary

**OVERALL PRODUCTION READINESS: 72%**

**VERDICT: NOT PRODUCTION READY**

The application is, on the merits of its engineering, in good shape: the
architecture is clean, the native wallpaper pipeline is disciplined, memory and
decoder concurrency are genuinely controlled, and there is zero TODO/FIXME/HACK
debt across ~24k lines of Dart and ~5.3k lines of Kotlin. It would very likely
behave well in users' hands.

It is nonetheless **not releasable today**, for one decisive reason that has
nothing to do with code quality: **`targetSdk = 34` is below the API level
Google Play now requires**, and that deadline (31 Aug 2026) has already passed
as of this audit (19 Sep 2026). The Play Console will reject the upload. A
second, coupled issue follows immediately from fixing it — raising the target to
API 35+ activates the 16 KB page-size obligation, and this build currently fails
the 16 KB ELF alignment check.

| Severity | Count |
|----------|------:|
| **P0** | 2 |
| **P1** | 3 |
| **P2** | 6 |
| **P3** | 5 |

**Strongest areas**
- Native wallpaper lifecycle & resource discipline (12 allocations / 12 recycles, every service pauses on `onVisibilityChanged`)
- Live-preview concurrency — hard cap of **1** decoder app-wide, enforced and tested
- Startup orchestration — nothing blocks first frame; ads/cache deferred post-frame
- Release-config safety — signing guard refuses to emit an unsigned AAB; ad IDs and logging both gated on `kReleaseMode`, not on a shippable `.env` flag
- Code hygiene — 0 TODO/FIXME/HACK, 0 localhost/staging references, 0 cleartext URLs

**Weakest areas**
- Google Play target-API compliance (**blocking**)
- 16 KB page-size readiness (**blocks the fix for the above**)
- No GDPR/UMP consent flow despite shipping four ad formats
- Zero native (Kotlin) tests and zero integration tests, over the code that does the actual rendering
- Working tree does not pass its own test suite (3 stale assertions)

---

## 2. Audit Environment

| Item | Value |
|------|-------|
| Flutter | 3.44.8 (stable, rev 058e0af2c2) |
| Dart | 3.12.2 |
| Engine | 13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939 |
| compileSdk | 36 (verified in artifact) |
| targetSdk | 34 (verified in artifact) |
| minSdk | 29 |
| Device | `emulator-5554` — sdk_gphone16k_x86_64 (Android 16, 16 KB page image) |
| Physical device | **None connected** — OPPO CPH1823 unavailable this session |
| Build type | `--release`, real upload keystore |
| Commit | `f5506ca` (branch `main`, 292 uncommitted files) |
| Package | `com.backgrounds.trend4k` v5.0.1 (versionCode 45) |
| Date | 19 September 2026 |

> The working tree carries 292 uncommitted files. The audit reflects the
> **working tree**, not commit `f5506ca`.

---

## 3. Validation Results

| Check | Result |
|-------|--------|
| `flutter clean` + `pub get` | ✅ Success |
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ❌ **406 passed / 3 failed / 0 skipped** |
| `flutter build apk --release` | ✅ **96.6 MB** (universal, 3 ABIs) |
| `flutter build appbundle --release` | ✅ **81.1 MB** |
| Release artifact inspection | ✅ Performed (`aapt2 badging`, zip listing, `.env` extraction) |
| Runtime smoke (emulator, release) | ✅ Cold start, all 4 tabs, scrolling, no crashes |
| Physical-device verification | ❌ **NOT VERIFIED** — no hardware connected |
| Integration tests | ❌ **None exist** (`integration_test/` absent) |

**The 3 failures are stale test assertions, not product defects** — see F-007.

---

## 4. Production Readiness Scorecard

| Area | Score | Status | Evidence | Main Risk |
|------|------:|--------|----------|-----------|
| Functional Correctness | 88 | Good | All 4 tabs + Live category VERIFIED on emulator; 406 tests green | Apply/Depth/Live unverified on real hardware |
| Stability | 85 | Good | No FATAL/E-flutter in release logcat; every bloc cancels in `close()` | Lifecycle regressions unverified on hardware |
| Performance | 78 | Fair | Median frame 8 ms MEASURED | 27.8% jank on emulator, unattributable |
| Startup Performance | 88 | Good | CODE-INSPECTED: only env/Hive/DI awaited pre-`runApp`; ads deferred post-frame | Real cold start unmeasured |
| Scrolling Performance | 75 | Fair | 607 frames MEASURED, p50 8 ms / p90 65 ms | Emulator-confounded |
| Memory Management | 85 | Good | PSS 223 MB / native heap 50 MB MEASURED after full nav | No long-soak test |
| Battery Efficiency | 82 | Good | All 3 services pause in `onVisibilityChanged` | No on-device battery measurement |
| Live Wallpaper Performance | 88 | Good | `maxConcurrent = 1` VERIFIED + tested; FIFO eviction | Applied LWS unverified on hardware |
| Depth Wallpaper Pipeline | 80 | Good | Fit-not-cover, viewport-correct, Latin clock pinned | Applied output unverified on hardware |
| Static Wallpaper Pipeline | 85 | Good | `fullUrl` for apply, `thumbnailUrl` in feed VERIFIED | Applied output unverified this session |
| Scalability | 72 | Fair | Cursor pagination + TTL cache CODE-INSPECTED | No pagination de-dupe (F-010) |
| Architecture | 92 | Strong | Clean feature/data/domain/presentation split, get_it DI | — |
| Code Quality | 94 | Strong | 0 TODO/FIXME/HACK; analyze clean | — |
| Networking | 85 | Good | HTTPS-only VERIFIED; typed error mapping | No request cancellation on dispose |
| Caching | 80 | Good | TTL + stale-while-revalidate; source-stamp invalidation | Unbounded image disk cache |
| Offline/Error Handling | 82 | Good | Offline never misread as ad-blocking (tested) | — |
| Security | 74 | Fair | No live secret in artifact VERIFIED; HTTPS-only | `.env` ships in APK (F-004); WebView unrestricted JS (F-009) |
| Privacy | 70 | Fair | Camera prominent disclosure correctly gates access | AD_ID permission needs Data Safety declaration (F-005) |
| Google Play Compliance | **35** | **Blocking** | `targetSdkVersion: 34` VERIFIED in artifact | **Upload will be rejected (F-001)** |
| AdMob/Ads Safety | 68 | Fair | Real IDs in release VERIFIED; single init | **No UMP/GDPR consent (F-003)**; dead interstitial (F-008) |
| Force Update | 55 | Weak | Fail-open VERIFIED (cannot lock users out) | `UPDATE_POLICY_URL` unset → feature inert (F-006) |
| In-App Review | 88 | Good | 2-apply trigger, once-per-version, no incentivisation | Play may suppress sheet (expected) |
| Ad-block Detection | 72 | Fair | Only named filtering DNS gates startup; VPN needs corroboration | Hard gate = reviewer-visible breakage (F-011) |
| Localization / RTL | 90 | Strong | EN/AR VERIFIED on device; brand pinned LTR; clock Latin-pinned | Unused `privacyBody`/`termsBody` |
| Accessibility | 74 | Fair | `Semantics` on cards/buttons CODE-INSPECTED | No font-scale or TalkBack testing |
| Testing | 62 | Weak | 406 passing across 64 files | **0 native, 0 integration; suite currently red** |
| Release Configuration | 80 | Good | Signing guard; correct ID/logging gating; 64-bit present | targetSdk; minify off; `.env` bundled |
| Maintainability | 92 | Strong | Consistent patterns, dense rationale comments | — |

---

## 5. Severity Summary

| Severity | Count |
|----------|------:|
| P0 | 2 |
| P1 | 3 |
| P2 | 6 |
| P3 | 5 |

---

## 6. Release Blockers

### F-001 — `targetSdk = 34` is below the current Play requirement — **P0**

- **Problem:** `android/app/build.gradle.kts:59` sets `targetSdk = 34`. Google Play has required **API 36** for new apps and updates since **31 Aug 2026**; API 35 is the floor merely to stay available to new users.
- **Evidence:** **VERIFIED in the built artifact** —
  `aapt2 dump badging app-release.apk` → `targetSdkVersion:'34'`.
  Requirement confirmed against `developer.android.com/google/play/requirements/target-sdk` (fetched during this audit, not recalled).
- **Affected files:** `android/app/build.gradle.kts:59`
- **User impact:** None directly; the app runs.
- **Release impact:** **The upload is rejected.** Nothing else in this report can ship until this changes.
- **Fix:** Set `targetSdk = 36`, then re-test the Android 15/16 behaviour changes that actually touch this app: edge-to-edge enforcement, foreground-service type validation (`camera`), and photo/media permission changes. This is not a one-line change — it requires a device pass.

### F-002 — Native libraries fail the 16 KB ELF alignment check — **P0 (coupled to F-001)**

- **Problem:** The emulator surfaced *"This app isn't 16 KB compatible. ELF alignment check failed."* Apps targeting API 35+ must support 16 KB page sizes; enforcement begins **1 Feb 2027**.
- **Evidence:** **VERIFIED at runtime** — system dialog on `sdk_gphone16k_x86_64` (a 16 KB page-size image). Requirement confirmed against `developer.android.com/guide/practices/page-sizes`.
- **Why P0 despite the 2027 date:** It is only dormant while `targetSdk ≤ 34`. Fixing F-001 — which is mandatory *now* — immediately makes this live. The two must be fixed together.
- **Affected:** Flutter engine `.so` files + plugin native libs across `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- **Fix:** Build with AGP 8.5.1+ / NDK r28+ (16 KB-aligned by default) and confirm every bundled `.so` — including `google_mobile_ads`, `video_player`, `webview_flutter` — is aligned. Re-test on the 16 KB emulator image.

---

## 7. Performance Audit

### Measured (emulator — `sdk_gphone16k_x86_64`, release build)

| Metric | Value | Method |
|--------|------:|--------|
| Cold start (`TotalTime`) | **3948 ms** | `am start -W` |
| — of which deliberate splash floor | 3000 ms | `SplashBloc._minDisplay` |
| — implied real init | **~950 ms** | derived |
| Home scroll, frames | 607 | `dumpsys gfxinfo` |
| Frame time p50 | **8 ms** | `dumpsys gfxinfo` |
| Frame time p90 | 65 ms | `dumpsys gfxinfo` |
| Frame time p99 | 117 ms | `dumpsys gfxinfo` |
| Janky frames | **27.8%** | `dumpsys gfxinfo` |
| TOTAL PSS | **223 MB** | `dumpsys meminfo` |
| Native heap | 50 MB | `dumpsys meminfo` |
| Dalvik heap | 30 MB | `dumpsys meminfo` |

> **Interpretation caveat, stated plainly:** an 8 ms median with 27.8% jank and a
> 4950 ms p99 GPU sample is the signature of **host-VM scheduling stalls**, not a
> rendering defect. An emulator cannot be used to accept or reject this app's
> smoothness. **Real-device frame data: NOT VERIFIED.**

### Code-inspected conclusions

- **Startup** — `lib/main.dart:15-19` awaits only dotenv → Hive → boxes → DI before `runApp`. `AdManager.initialize()` and cache housekeeping are `unawaited` inside `addPostFrameCallback` (`main.dart:27-34`). `SplashBloc` runs update + integrity gates concurrently via `Future.wait`. **No startup ANR vector from ads or integrity checks.**
- **Image pipeline** — feed binds `wallpaper.thumbnailUrl` (`mixed_wallpaper_feed_sliver.dart:196`) with `memCacheWidth/Height` capped to the card footprint (`wallpaper_card.dart:140-141`). Originals (`fullUrl`) are fetched only at apply time. **No 4K decode in the grid.**
- **Live previews** — `maxConcurrent = 1` (`live_wallpaper_player.dart:54`) with FIFO eviction and a 0.6 visibility threshold. **Exactly one decoder can run app-wide.**
- **Ads** — one `MobileAds.initialize()`; banners reuse a per-slot manager with a session-cached adaptive height (prevents the mid-scroll layout shift that previously caused feed jumps).

---

## 8. Scalability Audit

| Scale | Expected behaviour | Basis |
|-------|--------------------|-------|
| 100 / 1,000 wallpapers | Fine — lazy slivers, cursor pagination, capped decodes | CODE-INSPECTED |
| 10,000 wallpapers | Fine on screen; in-memory list grows unbounded per session but is released on tab change | CODE-INSPECTED |
| Large favorites | Fine — Hive keyed by wallpaper id, no duplicates; growth is user-bounded | CODE-INSPECTED |
| Slow / flaky network | Fine — 10 s connect / 30 s receive; TTL cache serves stale while revalidating | CODE-INSPECTED |
| Offline | Correct — offline is explicitly **not** classified as ad-blocking (covered by tests) | TESTED |
| Server reorders between pages | ⚠️ **Duplicate-key assertion risk** — see F-010 | CODE-INSPECTED |
| Disk image cache | ⚠️ No explicit ceiling; relies on `flutter_cache_manager` defaults | CODE-INSPECTED |

Architecture scales without a rewrite. The two soft spots are de-duplication and an explicit cache ceiling.

---

## 9. Stability Audit

**VERIFIED on emulator (release build):** cold start → Home; all four tabs navigate; sustained scrolling; no `FATAL`, no `E/flutter`.

**CODE-INSPECTED — clean:**
- Every bloc holding a subscription cancels it in `close()` (`connectivity_bloc.dart:42`, `favorites_bloc.dart:65`, `transparent_wallpaper_bloc.dart:222`).
- No `StatefulWidget` retains an undisposed controller/timer (`AppSearchBar` is stateless and merely accepts one; `SearchPage` disposes its own at `search_page.dart:40`).
- 32 catch blocks and 3 explicit `OutOfMemoryError` guards across native code.
- `MainActivity` uses `launchMode="singleTask"` with no `taskAffinity` override — the prior Apply→Splash-restart fix is intact.

**NOT VERIFIED (requires hardware):** apply→system-picker round trip, activity recreation under "Don't keep activities", rapid repeated Apply, process death mid-apply, rotation, real low-memory pressure.

---

## 10. Security Audit

| Check | Result | Evidence |
|-------|--------|----------|
| Live secret in artifact | ✅ **None** | `API_KEY=` extracted **empty** from packaged `.env` |
| `.env` committed to git | ✅ No | gitignored; `.env.example` is the template |
| `.env` shipped in APK | ⚠️ **Yes** — F-004 | `assets/flutter_assets/.env` (937 B) in APK |
| Cleartext traffic | ✅ None | no `http://` in `lib/`; no `usesCleartextTraffic` |
| TLS | ✅ HTTPS-only | API + legal pages both 200 over HTTPS |
| Exported components | ✅ Safe | all 3 wallpaper services require `BIND_WALLPAPER` (system-only); `CameraForegroundService` is `exported="false"` |
| Permissions | ✅ Justified | storage capped `maxSdkVersion=28`; camera `required=false` |
| Release debuggable | ✅ No | not set |
| Signing | ✅ Real upload key + task-graph guard | `key.properties` resolves to an existing keystore outside the repo |
| Sensitive logging | ✅ None | 54 native `Log.*` carry only diagnostic state — no PII/tokens/paths |
| WebView | ⚠️ Unrestricted JS, no nav allowlist — F-009 | `web_view_page.dart:36-49` |
| JS bridges | ✅ None | no `addJavaScriptChannel` |
| Dart logging in release | ✅ Gated | `loggingEnabled => !kReleaseMode && ...` (`app_config.dart:62`) |

---

## 11. Google Play Compliance Audit

| Requirement / Risk | Status | Severity | Evidence | Action Required |
|--------------------|--------|----------|----------|-----------------|
| Target API level | ❌ **PLAY BLOCKER** | **P0** | `targetSdkVersion:'34'` in artifact; API 36 required since 31 Aug 2026 | Raise to 36 + device re-test |
| 16 KB page size | ❌ **HIGH** (blocks F-001 fix) | **P0** | Runtime ELF alignment failure on 16 KB image | AGP 8.5.1+/NDK r28+, verify all `.so` |
| 64-bit libraries | ✅ COMPLIANT | — | `arm64-v8a` + `x86_64` present | — |
| GDPR/UMP consent | ❌ **HIGH REJECTION RISK** | **P1** | No `ConsentInformation`/UMP anywhere | Implement UMP before EEA/UK serving |
| AD_ID permission declaration | ⚠️ **MEDIUM** | **P1** | `com.google.android.gms.permission.AD_ID` in artifact | Declare in Data Safety form |
| Privacy policy accessible | ✅ COMPLIANT | — | Settings → About → Privacy Policy; URL live (200) | — |
| Camera prominent disclosure | ✅ COMPLIANT | — | `_ensureDisclosed()` gates all camera access; persisted | — |
| Foreground service type | ✅ COMPLIANT | — | `foregroundServiceType="camera"` + `FOREGROUND_SERVICE_CAMERA` | Re-verify under API 36 |
| Test ad IDs in release | ✅ COMPLIANT | — | real IDs selected via `kReleaseMode`; release manifest overrides App ID | — |
| Disruptive ads | ✅ LOW RISK | — | interstitial never shown; App Open only post-splash when preloaded | — |
| Incentivised reviews | ✅ COMPLIANT | — | no reward, no star-steering, once per version | — |
| Force-update UX | ✅ LOW RISK | — | fail-open; cannot lock out users | Feature inert (F-006) |
| Ad-block hard gate | ⚠️ **MEDIUM POLICY RISK** | **P2** | `canPop:false` gate on filtering DNS | Consider dismissible/limited mode |
| Broken functionality | ✅ LOW RISK | — | no crashes observed in release smoke | Needs hardware pass |
| Play Billing | ✅ N/A | — | PRO unlocks via rewarded ad, no purchases | — |
| Content/copyright | ⚠️ NOT ASSESSABLE | — | wallpaper rights are a business matter | Confirm licensing |

---

## 12. Advertising Audit

**Formats present:** Banner, App Open, Interstitial, Rewarded.

| Aspect | Finding |
|--------|---------|
| Initialization | ✅ Single `MobileAds.instance.initialize()`, wrapped in try/catch, deferred post-first-frame |
| Production IDs | ✅ `kReleaseMode && !FORCE_TEST_ADS` → real IDs; VERIFIED `FORCE_TEST_ADS=false` in artifact |
| App ID | ✅ Test ID is the main-manifest default; release manifest overrides via `tools:replace` |
| Banner | ✅ One persistent manager per slot; session-cached adaptive height prevents layout shift |
| App Open | ✅ Shown only after `SplashComplete`, only if already preloaded — never over a blocking gate |
| Interstitial | ⚠️ **Dead code** — preloaded every session with a 30 s retry loop, but **zero call sites** (F-008) |
| Rewarded | ✅ Single call site, gates PRO apply, always escapable via Cancel |
| Consent | ❌ **No UMP/GDPR flow** (F-003) |
| Accidental clicks | ✅ Low risk — banners are anchored siblings, not overlays |

---

## 13. Wallpaper Pipeline Audit

### Static — CODE-INSPECTED ✅ / hardware NOT VERIFIED
Apply reads `wallpaper.fullUrl` (the original, not a thumbnail). `decodeBounded()` downsamples toward screen resolution ×1.35 with a memory-headroom gate, never upscaling past source. `buildDeviceFitBitmap()` targets the **physical display**, fit-scales (never cover), and calls `suggestDesiredDimensions(display)` so the launcher is not handed a parallax-width canvas. `visibleCropHint` is `null`.

### Depth — CODE-INSPECTED ✅ / hardware NOT VERIFIED
`LiveWallpaperService` composes against a **visible viewport** (screen-sized rect centred in a possibly wider surface) rather than the raw surface; background and foreground share one fit scale so the cut-out stays registered with its scene; clock renders inside a translated viewport, preserving authored normalized position. Clock formatting is pinned to `Locale.US` — **guarded by tests** that reject any `Locale.getDefault()` in native code.

### Live / Video — CODE-INSPECTED ✅ / hardware NOT VERIFIED
`VideoWallpaperService` pauses on `onVisibilityChanged(false)`, releases `MediaPlayer` (`release()`), tears down the GL compositor, and removes handler callbacks on destroy. In-app previews are capped at **1 concurrent decoder**.

> **4K claim check:** the codebase makes no unqualified 4K claim. Catalog rows
> carry real dimensions (e.g. 2160×3840, 1080×1920, 941×1672) and `decodeBounded`
> explicitly refuses to upscale. **No misleading resolution claim found.**

---

## 14. Networking / Caching / Offline Audit

- **Transport:** Dio, HTTPS-only, 10 s connect / 30 s receive, typed failure mapping via `ApiInterceptor`. Bearer header added **only** when `apiKey` is non-empty.
- **Update policy fetch:** deliberately a **separate plain `Dio`** (not the shared client) with a short 5 s timeout, so a content-API change cannot break the update gate.
- **Caching:** Hive-backed `TimedCache` returning `(data, fresh)` — supports stale-while-revalidate. A `cacheSourceStamp` drops the cache when `MOCK_API` flips, preventing fixture rows leaking into a live session.
- **Offline:** connectivity is advisory — startup never fails on it, and offline is explicitly **not** classified as ad-blocking (test-covered).
- **Gap:** no request cancellation tied to widget disposal; a fast tab-switch lets in-flight responses land unused.

---

## 15. Architecture & Maintainability

Clean layered feature architecture: `features/<name>/{data,domain,presentation}` with `core/` for cross-cutting concerns. `get_it` DI, `flutter_bloc` state, `go_router` with a `StatefulShellRoute` for the 4 tabs.

**No circular dependencies, god objects, or unnecessary global state found.** Shared widgets are genuinely shared (one `WallpaperCard`, one feed-sliver builder used by Explore/Category/Search/Favorites). Comments consistently explain *why* — including the rationale for deliberate choices like R8 being off.

**One structural note:** `CategoryDetailsBloc` now branches on a reserved slug (`__live__`) to pick a different use case. Pragmatic and well-documented, but it is a special case inside a general component — worth revisiting if more pseudo-categories appear.

---

## 16. Localization / RTL / Accessibility

- **EN/AR** — full ARB coverage; **VERIFIED on device**: switching to Arabic re-renders the whole UI RTL.
- **Brand** — splash lock-up pinned `TextDirection.ltr`; **VERIFIED**: reads "Creative Backgrounds" LTR in both locales, same position, not mirrored, not translated.
- **Clock artwork** — pinned `en_US` / `Locale.US` in both Dart and Kotlin so applied wallpapers never render Arabic-Indic digits. Native guard test forbids `Locale.getDefault()`.
- **Accessibility** — `Semantics` present on cards, nav destinations and destination tiles; touch targets ≥48 dp.
- **Gaps — NOT VERIFIED:** large font-scale reflow, TalkBack traversal, contrast measurement.
- **Dead strings:** `privacyBody` and `termsBody` are unused (both pages now load remote URLs).

---

## 17. Complete Feature Inventory

| Feature | Status | Implementation | Backend | Native | Ads | Tests | Production Ready |
|---------|--------|----------------|---------|--------|-----|-------|------------------|
| Splash + entrance animation | WORKING | `features/splash/` | No | No | App Open after | ✅ | Yes |
| Startup gates (update + ad-integrity) | WORKING | `splash_bloc.dart` | Optional | Yes | No | ✅ | Yes |
| Explore / Home feed | WORKING | `features/explore/` | Yes | No | Banner /6 | ✅ | Yes |
| Search | PARTIALLY VERIFIED | `features/search/` | Yes | No | No | ❌ **none** | Yes (untested) |
| Categories tab (8 + Live) | WORKING | `features/categories/` | Yes | No | No | ✅ | Yes |
| Live Wallpapers pseudo-category | WORKING | `domain/live_category.dart` | `type=video` | No | No | ✅ | Yes |
| Category Details + pagination | WORKING | `category_details_page.dart` | Yes | No | 1 bottom banner | ✅ | Yes |
| Wallpaper Details | WORKING | `features/wallpaper_details/` | Yes | No | No | ✅ | Yes |
| Favorites | WORKING | `features/favorites/` | Local | No | No | ✅ | Yes |
| Apply sheet (Home/Lock/Both) | WORKING | `apply_wallpaper_page.dart` | No | Yes | Rewarded (PRO) | ✅ | Hardware unverified |
| Static wallpaper apply | NOT VERIFIED | `WallpaperApplyService.kt` | No | Yes | No | ⚠️ indirect | Hardware unverified |
| Depth wallpaper apply | NOT VERIFIED | `LiveWallpaperService.kt` + `DepthCompositor.kt` | Config | Yes | No | ⚠️ indirect | Hardware unverified |
| Live/video wallpaper apply | NOT VERIFIED | `VideoWallpaperService.kt` + `GLVideoClockCompositor.kt` | Yes | Yes | No | ❌ | Hardware unverified |
| Live preview in grid (1-decoder cap) | WORKING | `live_wallpaper_player.dart` | Yes | Yes | No | ✅ | Yes |
| Clock overlay (backend-configured) | WORKING | `ClockRenderer.kt` + `clock_painter.dart` | Yes | Yes | No | ✅ | Hardware unverified |
| Latin-digit clock (locale-independent) | WORKING | pinned `Locale.US` / `en_US` | No | Yes | No | ✅ | Applied output unverified |
| Transparent (camera) wallpaper | PARTIALLY VERIFIED | `features/transparent_wallpaper/` | No | Yes | No | ⚠️ 1 file | Hardware unverified |
| Camera prominent disclosure | WORKING | `transparent_control_sheet.dart:292` | No | No | No | ⚠️ | Yes |
| PRO / rewarded unlock | WORKING | `apply_wallpaper_page.dart:131` | Flag | No | Rewarded | ✅ | Yes |
| Banner ads | WORKING | `adaptive_banner_manager.dart` | No | No | Yes | ✅ | Yes |
| App Open ad | WORKING | `ad_manager.dart` | No | No | Yes | ✅ | Yes |
| Interstitial ad | **UNUSED/LEGACY** | `ad_manager.dart:206` | No | No | Yes | ❌ | **Dead (F-008)** |
| Force update | WORKING (inert) | `features/update/` | URL unset | No | No | ✅ | **Not configured (F-006)** |
| In-app review | WORKING | `features/review/` | No | No | No | ✅ | Yes |
| Ad-block / VPN / DNS detection | WORKING | `features/adblock/` | No | Yes | No | ✅ | Policy risk (F-011) |
| Settings (Language/Cache/Rate/Share/About) | WORKING | `settings_page.dart` | No | No | No | ⚠️ stale | Yes |
| Privacy Policy (WebView) | WORKING | `privacy_policy_page.dart` | URL 200 | No | No | ❌ | Yes |
| Terms of Service (WebView) | WORKING | `terms_page.dart` | URL 200 | No | No | ❌ | Yes |
| About | WORKING | `about_page.dart` | No | No | No | ✅ | Yes |
| EN/AR localization + RTL | WORKING | `core/l10n/` | No | No | No | ✅ | Yes |
| Connectivity monitoring | WORKING | `features/connectivity/` | No | No | No | ❌ **none** | Yes (untested) |
| Shimmer / error / empty states | WORKING | `core/widgets/` | No | No | No | ✅ | Yes |

**31 user-facing features discovered.**

---

## 18. Dead / Legacy Code

*Reported only — nothing was deleted.*

| Item | Location | Note |
|------|----------|------|
| Interstitial ad pipeline | `ad_manager.dart:206-238` | Preloaded + retried every session; **zero call sites** since View All was removed |
| `privacyBody` string | `app_en.arb` / `app_ar.arb` | Unused — page loads a remote URL |
| `termsBody` string | `app_en.arb` / `app_ar.arb` | Unused — page loads a remote URL |
| `AppVersion` entity | `features/update/domain/entities/app_version.dart` | Superseded by build-number comparison; still has its own passing tests |
| Fixture assets | `assets/fixtures/` (13 KB) | Only reachable when `MOCK_API=true`; ships in release |

**Confirmed properly removed:** `customize/`, `view_all/`, `premium/` — no residue.

---

## 19. Test Coverage

| Metric | Value |
|--------|------:|
| Test files | 64 |
| Tests passing | **406** |
| Tests failing | **3** |
| Tests skipped | 0 |
| Widget-test files | 26 |
| Unit-test files | 38 |
| **Native (Kotlin) tests** | **0** |
| **Integration tests** | **0** |

**Well covered:** force-update matrix incl. fail-safe; review trigger + anti-spam; ad-integrity false-positive protection; clock Latin digits (incl. a native-source guard); splash brand LTR; Live category type-filtering; category layout/ads; DI resolution.

**No meaningful coverage:**
- **All native rendering** (~5.3k lines of Kotlin) — the code that actually produces wallpapers
- **Search** (0 files)
- **Connectivity** (0 files)
- **Apply → system picker → return** round trip
- **Camera/transparent wallpaper engine**

> 406 green tests is a healthy number, but the untested surface is precisely the
> surface that is hardest to fix after release: native rendering and the apply
> pipeline.

---

## 20. Release Artifact Inspection

**Performed on `build/app/outputs/flutter-apk/app-release.apk` (96.6 MB) and `app-release.aab` (81.1 MB).**

| Finding | Value |
|---------|-------|
| Package / version | `com.backgrounds.trend4k`, 5.0.1 (45) |
| compile / target / min SDK | 36 / **34** / 29 |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` (64-bit ✅) |
| Non-arm64 ABI weight | 36.0 MB → arm64 download ≈ **45–50 MB** (well under Play's 200 MB limit) |
| `.env` packaged | ⚠️ **Yes** — `assets/flutter_assets/.env`, 937 B, extracted and read |
| `API_KEY` in artifact | ✅ **Empty** — no credential leak |
| `MOCK_API` / `FORCE_TEST_ADS` in artifact | ✅ Both `false` |
| `UPDATE_POLICY_URL` in artifact | ⚠️ **Absent** — update gate inert |
| Keystore / `key.properties` in artifact | ✅ Not present |
| Largest assets | `space.png` 2.73 MB, `nature.png` 2.65 MB (20 MB of category PNGs total) |
| AD_ID permission | Present (transitive from AdMob) |

---

## 21. Remaining Issues

| ID | Severity | Area | Problem | Impact | Required Before Release? | Recommended Fix |
|----|----------|------|---------|--------|--------------------------|-----------------|
| F-001 | **P0** | Play Compliance | `targetSdk = 34`; Play requires API 36 since 31 Aug 2026 | Upload rejected | **YES** | Raise to 36; re-test edge-to-edge, FGS types, media permissions on device |
| F-002 | **P0** | Native / Play | Native libs fail 16 KB ELF alignment | Blocks F-001; update-blocking from 1 Feb 2027 | **YES** (with F-001) | AGP 8.5.1+/NDK r28+; verify every `.so`; test on 16 KB image |
| F-003 | **P1** | Ads / Privacy | No UMP/GDPR consent flow with 4 ad formats | AdMob policy violation for EEA/UK | **YES** | Integrate UMP consent before ad requests |
| F-004 | **P1** | Security | `.env` bundled as a Flutter asset → extractable | No secret today; leaks any future key | **YES** (harden) | Move secrets to `--dart-define`; keep only non-sensitive flags |
| F-005 | **P1** | Privacy | `AD_ID` permission ships undeclared | Data Safety mismatch | **YES** | Declare advertising ID in Play Data Safety |
| F-006 | P2 | Force Update | `UPDATE_POLICY_URL` unset → feature inert | No remote kill switch | Recommended | Host policy JSON; set the env var |
| F-007 | P2 | Testing | 3 stale test assertions fail (8-vs-9 categories; Privacy row moved to About) | Red suite masks real regressions | **YES** (cheap) | Update the 3 assertions |
| F-008 | P2 | Ads | Interstitial preloaded + retried but never shown | Wasted bandwidth/requests each session | Recommended | Remove the pipeline or wire a call site |
| F-009 | P2 | Security | WebView `JavaScriptMode.unrestricted`, no nav allowlist | Bounded, but unconstrained navigation | Recommended | Add `onNavigationRequest` host allowlist |
| F-010 | P2 | Scalability | Pagination appends without de-dupe | Duplicate `ValueKey` assertion if server reorders | Recommended | De-dupe by id on append |
| F-011 | P2 | Play Policy | Ad-block gate is hard (`canPop:false`) | Reviewer on filtering DNS sees a bricked app | Recommended | Make dismissible or degrade gracefully |
| F-012 | P3 | Size | 20 MB of category PNGs at ~2.2–2.7 MB each | Larger download than necessary | No | Re-encode to WebP (~80% smaller) |
| F-013 | P3 | Release Config | R8/resource shrinking disabled | Larger APK, no obfuscation | No | Enable with a tested keep-ruleset, as its own change |
| F-014 | P3 | Native | 54 `Log.*` calls ungated in release | Log noise (no PII) | No | Gate on `BuildConfig.DEBUG` |
| F-015 | P3 | Dead Code | `privacyBody`, `termsBody`, `AppVersion`, fixtures unused | Maintenance noise | No | Remove in a cleanup pass |
| F-016 | P3 | Networking | No request cancellation on dispose | Minor wasted bandwidth | No | Attach `CancelToken` to widget lifecycle |

---

## 22. Required Before Release

1. **F-001** — `targetSdk = 36` + device re-test. *Hard blocker.*
2. **F-002** — 16 KB ELF alignment (AGP/NDK upgrade). *Coupled to #1.*
3. **F-003** — UMP/GDPR consent before serving ads.
4. **F-005** — Declare `AD_ID` in Play Data Safety.
5. **F-004** — Stop bundling `.env`; move any secret to `--dart-define`.
6. **F-007** — Fix the 3 stale tests so the suite is green.
7. **Physical-device pass** — apply Static/Depth/Live on real hardware, incl. the Arabic applied clock and launcher behaviour. **None of this is currently verified.**

---

## 23. Recommended After Release

- F-006 host the update-policy document and enable the kill switch
- F-008 remove or wire up the interstitial
- F-009 WebView navigation allowlist
- F-010 pagination de-dupe
- F-011 soften the ad-block gate
- F-012 WebP category covers (~16 MB saving)
- F-013 enable R8 with a tested keep-ruleset
- Add native (Kotlin) and integration tests for the apply pipeline
- Add Search and connectivity tests

---

## 24. Final Score

Weighted toward the areas that actually decide a release: compliance, stability,
security, functionality, performance, release configuration.

```
Functional Correctness ........  88%
Stability .....................  85%
Performance ...................  78%
Startup Performance ...........  88%
Scrolling Performance .........  75%
Memory Management .............  85%
Battery Efficiency ............  82%
Live Wallpaper Performance ....  88%
Depth Wallpaper Pipeline ......  80%
Static Wallpaper Pipeline .....  85%
Scalability ...................  72%
Architecture ..................  92%
Code Quality ..................  94%
Networking ....................  85%
Caching .......................  80%
Offline / Error Handling ......  82%
Security ......................  74%
Privacy .......................  70%
Google Play Compliance ........  35%   ← 2 × P0
AdMob / Ads Safety ............  68%
Force Update ..................  55%
In-App Review .................  88%
Ad-block Detection ............  72%
Localization / RTL ............  90%
Accessibility .................  74%
Testing .......................  62%
Release Configuration .........  80%
Maintainability ...............  92%

Weighted subtotal (engineering quality) ....... ~82%
P0 compliance cap applied ..................... −10
OVERALL PRODUCTION READINESS: 72%
```

**Why 72% and not higher:** the engineering is genuinely strong — an unweighted
read of the scorecard lands near 80%. But two P0s sit on the single axis that is
binary rather than graded: the build **cannot be accepted by Google Play** in its
current form. A high-quality app that cannot be uploaded is not production-ready,
so compliance is scored at 35% and caps the total.

**Why 72% and not lower:** none of the blockers are architectural. F-001 is a
build-config value; F-002 is a toolchain upgrade. There is no crash, no data
loss, no leaked secret, and no broken user-facing flow. The remaining work is
configuration and verification — not redesign.

---

## 25. Final Verdict

# NOT PRODUCTION READY

1. `targetSdk = 34` is below Play's current API 36 requirement (deadline passed 31 Aug 2026) — the upload will be rejected. This alone is decisive.
2. Raising the target activates the 16 KB page-size obligation, which this build currently fails; the two must be fixed together.
3. Four ad formats ship with no UMP/GDPR consent flow — an AdMob policy violation for EEA/UK users.
4. The `AD_ID` permission ships without a corresponding Data Safety declaration.
5. `.env` is packaged inside the APK; harmless today (the key is empty) but unsafe as a pattern.
6. The working tree fails its own test suite — 3 stale assertions, cheap to fix, but a red suite hides real regressions.
7. **No physical-device verification was possible this session**: wallpaper apply, Depth/Live rendering, the Arabic applied clock and launcher behaviour are all unverified.
8. Everything else is in good order — clean architecture, disciplined native resource handling, a real 1-decoder cap, correct ad-ID and logging gating, and a signing guard that refuses to emit an unsigned bundle.
9. No finding requires redesign; all remaining work is configuration, consent, and verification.
10. Realistic path to release: **2–4 days**, dominated by the API 36 + 16 KB device re-test, not by code changes.
