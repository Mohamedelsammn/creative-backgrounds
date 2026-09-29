# Performance optimization report

**Date:** 2026-09-13  
**Scope:** Home feed, live previews, banner lifecycle, startup, splash, and
bottom navigation.  
**Important evidence boundary:** the requested OPPO device was not connected
to this workspace. The before figures below are the existing profile-mode
emulator captures recorded in `docs/PRODUCTION_READINESS_AUDIT.md`; no
after-device number is claimed until the same matrix is run on hardware.

## 1. Initial symptoms and baseline

The reported physical-device symptom is credible: Home is smooth before
dynamic content becomes active, then becomes heavy when banners and live
previews arrive. The prior profile capture measured 26.98–34.94% janky frames,
with P90 46–200 ms and P99 93–400 ms during Home swipes. This is well beyond a
60 Hz frame budget (16.67 ms), so it is not classified as debug-only overhead.

No OPPO, GPU trace, native heap capture, or release-profile trace was available
in this session. Consequently, live-preview/ad/blur/image/rebuild percentage
contributions and before/after CPU, memory, startup, and jank percentages are
**not measurable yet**. They must not be inferred from static code.

## 2. Root causes ranked by expected impact

1. **Dynamic bottom navigation blur:** `BackdropFilter` sampled the actively
   scrolling Home framebuffer every frame. The earlier sigma-10 reduction
   improved worst-frame duration but left 24–31% jank in clean samples.
2. **Concurrent live decoders:** the existing global cap was two. Multiple
   video textures/platform views could still contend with image decoding and
   scrolling on an older phone.
3. **Live playback during fling:** visibility was gated, but there was no
   Home-level pause while vertical scroll was in motion, so decoder work could
   overlap every ballistic-scroll frame.
4. **Banner arrival layout work:** unloaded banners collapsed to zero height;
   loading an adaptive platform view inserted a new sliver height underneath a
   user, causing layout/scroll-offset churn.
5. **Startup critical path:** splash waited for the full ad-integrity probe.
   That probe can await ad requests for up to 10 seconds (and can retry on the
   first run), which directly explains the observed multi-second dead period.
6. **Splash raster work:** an always-ticking, full-screen multi-gradient
   painter competed with startup work during the first frames.

Home is already a `CustomScrollView` with lazy horizontal child lists and
conservative horizontal cache extents; it was not a large eager `Column`.
Wallpaper-card posters already use their rendered pixel width as
`memCacheWidth`, so no source-resolution decode regression was found.

## 3. Changes implemented

### Live wallpapers

- Reduced the process-wide decoder cap from **two to one**.
- Added a shared `LivePreviewPlaybackGate` to Home cards. Vertical scroll
  start/update pauses and releases all live resources immediately; playback is
  eligible only 180 ms after scrolling settles.
- Added lifecycle release at the player itself. Inactive/background state
  releases both `VideoPlayerController` and the native `MediaPlayerPreview`.
- Off-screen cards continue to dispose their active resource rather than only
  pausing. URL resolution remains lazy and cancelled when visibility is lost.
- Feed previews remain muted. The details player retains priority for the sole
  active slot.

**Maximum active previews:** before 2; after 1. Off-screen decoders are
released before and after this pass; this pass also releases visible decoders
during a fast Home scroll.

### Bottom navigation and GPU

The production bottom navigation no longer uses `BackdropFilter` or
`ImageFilter.blur`. It preserves the same pill, white translucent surface,
border, shadow, icons, spacing, and selected indicator without framebuffer
readback. This is the largest directly targeted raster-cost removal.

### Ads

- Banner size is observable and a standard banner-height slot is reserved
  while an adaptive banner loads. The loaded platform view remains isolated in
  a `RepaintBoundary`.
- Banner manager identity is still stable per Home slot and loading remains
  idempotent, preventing a rebuild from creating/reloading ads.
- Ads are not disabled and no serving rule was changed.

### Images and Home rendering

- Preserved card-size `memCacheWidth` poster/image decoding.
- Set the vertical Home sliver cache to a conservative 200 logical pixels, so
  media-heavy sections are not created far beyond the viewport.
- Preserved the existing lazy `CustomScrollView`/`PageView.builder`/
  `ListView.separated` architecture and rebuild isolation in carousel scale
  animations.

### Startup and splash

- `runApp` now happens before cache-source invalidation and Mobile Ads SDK
  initialization. Both run after the first frame instead of competing with it.
- Splash now waits only for local initialization, the mandatory update check,
  a lightweight local VPN/private-DNS signal check, and the 1.5-second
  branding minimum. It no longer waits for ad inventory/network probes.
- Full ad-integrity probing remains available, but it is no longer allowed to
  make the first usable Home frame wait on an ad request.
- App Open ads now show only if already loaded, after Home has been routed and
  given 750 ms to become interactive; Home never waits for the previous
  up-to-eight-second ad-load wait.
- Replaced the splash's continuous full-screen ambient animation with a static
  cached background; the card/name entrance animation remains visible.

## 4. Measurement matrix to complete on the OPPO device

Use a release or profile build and record Flutter frame timings plus
`adb shell dumpsys gfxinfo <package>`. Reset gfxinfo between rows. Capture CPU,
native/Dart/graphics memory, active controller count, banner count, and logcat
timestamps for process start, first frame, Home ready, and any full-screen ad.

| Scenario | Required comparison |
|---|---|
| Home first paint | baseline vs. combined optimization |
| Banners loaded | normal vs. banners omitted diagnostic build |
| Live section visible | normal vs. playback-gate disabled diagnostic build |
| Slow scroll / fast fling | decoder count, UI/raster frame time, jank % |
| Live cards off-screen | controller/native-player count must return to 0 |
| Bottom nav | static translucent surface vs. prior sigma-10 blur |
| Cold launch | process start → first frame → Home ready |
| Startup ad | ready ad vs. no ready ad; Home must not wait |
| Five-minute idle | CPU/memory plateau with no invisible preview playback |

Report each row at the device refresh-rate budget. Do not report percentage
contribution until A/B traces are collected; record it as
`(A_jank - B_jank) / A_jank` only when the swipe sequence and device state are
equivalent.

## 5. Validation and remaining risks

- Targeted static analysis of all changed production files: **clean**.
- Added widget coverage for the Home playback gate and changed concurrency
  expectations to enforce one active preview.
- Full `flutter analyze`, `flutter test`, and release AAB validation remain
  pending because this workspace's Flutter wrapper is blocked on its global
  SDK lock; direct Dart analysis was used for the targeted static check.
- Physical OPPO validation remains mandatory. Native Android platform-view ad
  cost and vendor-specific codec behavior cannot be proven by Dart tests.
- If the OPPO trace still shows sustained jank with one paused/released
  preview and no backdrop blur, collect a Perfetto trace next and request
  lower-resolution/bitrate feed-preview media from the backend. Final applied
  wallpaper quality must remain unchanged.

## 6. Files changed in this pass

- `lib/core/widgets/live_preview_playback_gate.dart`
- `lib/core/widgets/live_wallpaper_player.dart`
- `lib/core/widgets/wallpaper_card.dart`
- `lib/features/explore/presentation/pages/explore_page.dart`
- `lib/features/explore/presentation/widgets/{peek_carousel,latest_carousel,trending_carousel,category_carousel}.dart`
- `lib/core/widgets/floating_bottom_nav.dart`
- `lib/core/ads/adaptive_banner_manager.dart`
- `lib/core/widgets/adaptive_banner_ad.dart`
- `lib/main.dart`
- `lib/features/splash/presentation/{bloc/splash_bloc.dart,pages/splash_page.dart,widgets/premium_splash_animation.dart}`
- `lib/features/adblock/data/services/ad_integrity_service.dart`
- `test/live_wallpaper_player_{concurrency_cap,priority_slot,visibility_disposal}_test.dart`
- `test/splash_bloc_error_recovery_test.dart`

## Physical Device Verification

**Verified on:** 2026-09-13

### Source and static validation

The optimized source state was rechecked and still contains the intended
implementation: one global decoder, the Home scroll playback gate,
off-screen/lifecycle release, no bottom-nav `BackdropFilter`, reserved banner
height, 200px vertical scroll cache extent, post-first-frame noncritical
startup work, startup-safe ad-integrity handling, delayed ready-only App Open
behavior, and the static splash background with retained card/name animation.

`flutter pub get` completed. `flutter analyze` completed with **no issues**.

The first machine-reporter full test attempt exposed two stale expectations in
`live_wallpaper_player_locked_tree_test.dart`: both expected the superseded
two-decoder cap. This was a reproducible test-only mismatch, not a runtime
lifecycle failure. The assertions were updated to the production one-decoder
policy; the two targeted lifecycle tests then passed. A fresh full
machine-readable test run reached its terminal `done` event successfully:

| Result | Count |
|---|---:|
| Passed | 392 |
| Failed | 0 |
| Skipped | 0 |
| Total | 392 |

### Release artifact

`flutter build appbundle --release` completed successfully in 64.1 seconds.
The artifact exists at
`build/app/outputs/bundle/release/app-release.aab` and is **67,777,886 bytes
(64.6 MB)**. `jarsigner -verify -certs` returned exit code 0 and reported
`jar verified`. Its warnings identify a self-signed, non-timestamped upload
certificate; that confirms a signed bundle but is not an independent Play
certificate-chain trust assertion.

### Connected OPPO

| Field | Observed value |
|---|---|
| Serial | `8DTKUKNN4H49VGMR` |
| Model | `CPH1823` |
| Android | 10 |
| ABI | `arm64-v8a` |
| RAM | 3,744,408 kB (about 3.57 GiB) |
| Display | 1080 x 2340, density 480 |
| Reported peak refresh rate | 130 Hz |

The device initially appeared offline, then was successfully recovered with
`adb reconnect offline` and became usable. A current profile APK was built
successfully (`app-profile.apk`, 105,155,501 bytes), but the OPPO rejected both
normal streamed and non-streaming updates with
`INSTALL_FAILED_VERIFICATION_FAILURE`. The device has
`verifier_verify_adb_installs=1`. Its currently installed package is version
`5.0.1` / code 45, last updated at 2026-09-13 16:38:42 by
`com.coloros.filemanager`; it cannot be proven to be the newly built profile
APK and was not used as performance evidence.

### Measurement result

No valid optimized profile/release binary could be installed, so the required
OPPO Home jank, decoder-count, startup, splash, banner, CPU, memory, and
five-minute-idle measurements were **not collected**. There is therefore no
measured evidence yet for initial Home, fully loaded Home, live section, fast
fling, App Open sequencing, or functional regression on the physical device.
No controlled feature-disable runs or Perfetto trace were performed, because
they would not measure the optimized implementation.

**Next unblock:** on the OPPO, authorize USB debugging and permit installation
from USB/ADB (or have the owner install the generated profile APK through the
device-approved path). Then rerun the Phase 5–10 matrix against the installed
profile binary and capture `dumpsys gfxinfo` after each reset. Do not claim a
performance result from the existing unknown-installed binary.
