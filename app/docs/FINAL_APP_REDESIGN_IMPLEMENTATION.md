# Final App Redesign Implementation

**Application:** Creative Backgrounds
**Scope:** Discover → Preview → Apply redesign — Dashboard-authored wallpapers, no mobile customization
**Status:** Implemented, verified via `flutter analyze`/`flutter test`, both release artifacts build, and a manual on-device pass on the Android emulator

> Supersedes the customization-era description in `DEPTH_WALLPAPER_FEATURE_SPEC.md` and `DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md` — those documents describe the Customize feature this redesign removes. Their still-relevant portions (native rendering pipeline, `ClockConfigEntity`/`DepthRenderConfig` shapes, backend mapping) remain accurate; their Customize-UI sections do not.

## 1. Old architecture

The mobile app let the user edit a wallpaper's clock (style, font, weight, color, position, effects, date) and depth on/off state via a "Customize" screen (`DepthCustomizeView`, plus a dead, unreachable `CustomizePage`/`/customize/:wallpaperId` route). `ClockBloc`/`DepthBloc` held that in-memory editing state, backed by `ClockRepositoryImpl` (Hive-persisted per-wallpaper override, taking precedence over the backend's authored default) and `DepthBloc`'s on/off toggle. Explore was a sectioned page: Trending carousel, Depth-only carousel, Live-only carousel, then one horizontal carousel per category — each with its own "View All" link into a separate `view_all` feature with its own filter/sort bottom sheets. Bottom navigation had three tabs (Explore, Favorites, Settings); Categories existed only as those Explore carousels. Settings had Language, Clear cache, and About — no Rate/Share/Privacy Policy rows.

## 2. New architecture

The mobile user only discovers, previews, favorites, and applies — the Dashboard/backend is the sole author of a wallpaper's finished appearance (clock config, depth composition, video+clock). Four tabs: Explore, Categories, Favorites, Settings. Explore is one continuous mixed feed instead of typed sections. Categories is a new top-level tab with its own Details page. No screen writes a clock or depth override; Apply always uses the wallpaper's own `remoteClockConfig`/depth capability, read directly off `WallpaperEntity`.

## 3. Removed Customize functionality

Deleted entirely:
- `lib/features/customize/` — `CustomizePage` (the dead route), `DepthCustomizeView` (the live entry, previously reached from Details via a raw `MaterialPageRoute`), `CustomizeBloc`, `ClockSettingsPanel`, `ClockStylesPanel`, `ClockStyleCard`, `DepthSettingsPanel`.
- `lib/features/clock/presentation/widgets/draggable_clock_overlay.dart` (Customize-only drag-to-position UX).
- `lib/core/widgets/custom_color_picker_sheet.dart` (Customize-only color picker).
- The entire user-editing chain now that nothing writes an override: `ClockBloc`/event/state, `LoadClockConfigUseCase`, `SaveClockConfigUseCase`, `ClockRepository`/`ClockRepositoryImpl`, `ClockChannel` (Dart side — the native `com.backgrounds.trend4k/clock` channel handler in `ClockChannel.kt` is now unreferenced from Dart and can be removed from `MainActivity.kt` in a future native cleanup pass; left in place this round since an idle registered channel is harmless), `DepthBloc`/event/state, `SaveDepthConfigUseCase`, `DepthRepository`/`DepthRepositoryImpl`.
- The now-unreachable `view_all` feature in full (`ViewAllBloc`, `ViewAllRepository`, `GetSectionWallpapersUseCase`, `ViewAllPage`, `FilterBottomSheet`, `SortBottomSheet`, `CategoryChipRow`) and the `/view-all/:section` route — nothing pushes to it once Explore's per-category "View All" links and typed-section headers are gone.
- Explore's old section widgets: `TrendingCarousel`, `LatestCarousel`, `CategoryCarousel`, `PeekCarousel`.
- `WallpaperGridSkeleton` (only consumer was View All).
- ~19 test files covering the above (Customize screens/panels, drag-to-position, the old sectioned Explore, View All, the removed skeleton).

`context.l10n.customize` and the Customize-only ARB strings were left in `app_en.arb`/`app_ar.arb` (unused now but harmless — a full l10n-key audit was out of scope for this pass).

## 4. Retained rendering infrastructure

Deliberately **not** deleted, because Dashboard-authored rendering still depends on it:
- `ClockConfigEntity`, `ClockConfigModel` (+ freezed/g), `RemoteClockConfigMapper` — the backend→entity parsing that makes `WallpaperEntity.remoteClockConfig` the single source of truth.
- `ClockPainter`, `ClockLayoutEngine`, `ClockRendererWidget` (`features/clock/presentation/widgets/`) — genuinely decoupled from Customize already; still used by `DepthLayerStack`.
- `features/depth/` — `DepthConfigEntity` (now read-only: Apply derives it from `wallpaper.supportsDepth`, never from a user toggle), `DepthLayerStack`, `DepthPreviewWidget`.
- Native: `ClockConfig.kt`, `ClockRenderer.kt`, `ClockLayoutEngine.kt`, `ClockStylePreset.kt`, `DepthCompositor.kt`, `GLVideoClockCompositor.kt`, `VideoWallpaperService.kt`, `LiveWallpaperService.kt` — entirely unaffected; they already read persisted SharedPreferences written at apply time, never a Dart bloc.

## 5. New navigation

`FloatingBottomNav.defaultDestinations` now lists 4 entries — Explore (compass), Categories (grid), Favorites (heart), Settings (gear, was previously a sun icon) — the spring/drag/RTL math is destination-count-agnostic and needed no changes. `MainShell`'s `StatefulShellRoute.indexedStack` has 4 branches in the same order (branch index must equal nav index). `RouteNames.customize`/`viewAll` removed; `RouteNames.categories` (`/categories`, tab) and `RouteNames.categoryDetails` (`/categories/:slug`, push, outside the shell — no bottom nav) added.

## 6. Explore implementation

`ExploreBloc` was rewritten from a parallel trending+live+depth+categories fetch (no pagination) to a single cursor-paginated stream: `GetNewWallpapersUseCase` → `ExploreRepository.getNewWallpapers()` → `WallpaperFeedApi.feed(sort: FeedSort.newest)`, mirroring `ViewAllBloc`'s former load-more/cursor shape. `ExploreState.ExploreLoaded` carries `wallpapers`/`hasMore`/`isLoadingMore`; `ExploreLoadMoreRequested` appends using the previous page's `nextCursor`, `ExploreRefreshRequested` bypasses the Hive cache (`StorageKeys.cacheLatest`, previously reserved but unused).

## 7. Mixed feed behavior

`buildMixedWallpaperFeedSlivers` (`lib/core/widgets/mixed_wallpaper_feed_sliver.dart`) renders the flat wallpaper list as `SliverMasonryGrid.count` groups of 6, each followed by an ad slot — never mid-group. Position is counted globally across pages (6/12/18 regardless of API page boundaries), matching the spec's explicit example. Cards reuse the existing `WallpaperCard` verbatim (badges, PRO, decode-size capping, `LiveWallpaperPlayer` for live cards) — no new card implementation.

## 8. Badges

Unchanged — `WallpaperTypeBadge`/`ProBadge`, already correctly type/PRO-driven, reused as-is across Explore, Categories, Category Details, Favorites, Search.

## 9. Ad insertion

Every 6th wallpaper item gets a full-width `AdaptiveBannerAd`, keyed by a stable `slot` index (`ValueKey('mixed_feed_ad_slot_$slot')`) so ad identity survives list growth exactly like Explore's previous between-sections banners did. One `AdaptiveBannerManager` per slot, created lazily and held for the widget's lifetime.

## 10. Live preview policy

Unchanged and re-verified under the new grid: `_ActiveVideoRegistry` inside `live_wallpaper_player.dart` still caps concurrent decoding to exactly 1 across the whole app (`maxConcurrent = 1`), with Details holding a priority slot. The mixed feed attaches the same `LivePreviewPlaybackGate` Explore already used (pause on scroll start, resume 300ms after scroll settles) — no new gating code.

## 11. Categories

New feature (`lib/features/categories/`): `CategoriesPage` (tab root) shows large horizontal cards — background image, name, `$count Wallpapers`, chevron — from `GetCategoriesUseCase` (reused, no new categories fetch). `CategoriesBloc` is a minimal fetch-once bloc, kept in the same event/state style as the rest of the codebase rather than introducing a one-off Cubit.

## 12. Category Details

`CategoryDetailsPage` (push route `/categories/:slug`): back + name + count header, then `WallpaperGrid` (the same infinite-scroll masonry grid Search already used) paginated via `CategoryDetailsBloc` → `GetCategoryWallpapersUseCase` → `WallpaperFeedApi.feed(categorySlug:, sort: newest)` — this exact backend call already existed (previously powering Explore's per-category carousels); Category Details is its only consumer now.

## 13. Favorites

Unchanged — already matched the spec (heart-based grid, local Hive storage, shared `WallpaperCard`).

## 14. Settings

Added three rows that did not exist before: **Rate the app** (opens `UpdateConfig.playStoreUrl` via `url_launcher`, same pattern as the existing mandatory-update screen), **Share app** (`share_plus`'s `Share.share`, same package already used by Wallpaper Details' share action), **Privacy Policy** (was previously nested one level down inside About; now also a direct Settings row per spec, `RouteNames.privacy` already existed). Final row order: Language, Clear cache, Rate the app, Share app, Privacy Policy, About. No Premium row was ever present — confirmed, not removed.

## 15. Details

`WallpaperInfoPanel` lost its `onCustomize` param/CTA. A Live wallpaper gets a compact circular Play/Pause button beside the single full-width Apply button (never overlaid on the video) — backed by a `LivePreviewPlaybackGate` instance owned by `_DetailsViewState`, independent of Explore's shared feed-wide gate, toggled via `ValueListenableBuilder`. Apply's `depthConfig`/`clockConfig` are now derived directly from the wallpaper (`wallpaper.remoteClockConfig`, `wallpaper.supportsDepth`) inside a new `_apply()` helper — **this closes a real regression risk**: without it, a depth wallpaper's Apply call would have passed no `depthConfig` at all once Customize's config-passing call site was deleted, silently applying the flattened image instead of the depth composite.

## 16. Apply flow

`showApplyWallpaperSheet` unchanged in signature/logic (Home/Lock/Both for static, single "Set as live wallpaper" for clock/depth/live, PRO rewarded-ad gate). Added a small phone-proportioned preview thumbnail (`_PreviewThumbnail`, 96×160, bounded decode) above the "Apply to…" title. Wrapped the sheet's content in `SingleChildScrollView` so the added thumbnail can never overflow on a short viewport.

## 17. Normal pipeline

Unchanged. `ApplyWallpaperRepositoryImpl` already downloaded `wallpaper.fullUrl` (the full-resolution original), not a thumbnail.

## 18. Depth pipeline

Unchanged rendering; the apply-time enable decision moved from a user `DepthBloc` toggle to a direct read of `wallpaper.supportsDepth` (see §15) — the only behavioral change, and it's what keeps depth wallpapers actually applying with their effect now that there's no toggle UI.

## 19. Live pipeline

Unchanged native compositor/decoder-cap architecture. Dart-side Details now offers Play/Pause; the applied wallpaper's own dynamic clock rendering (native `GLVideoClockCompositor`) is untouched.

## 20. Dashboard config mapping

Unchanged — `RemoteClockConfigMapper`, `WallpaperModel.fromApiFeedItem`/`fromApiDetail`, `DepthRenderConfig`. Category Details' pagination reuses the exact same `categorySlug` server-side filter Explore's old carousels used (`WallpaperFeedApi.feed(categorySlug:)`) — the "AMOLED/Cars View All comes back empty" slug-vs-id bug this filter was written to fix cannot recur here since Category Details never goes through a filter-sheet layer.

## 21. Image-quality pipeline

Native `WallpaperApplyService.decodeBounded()` now targets `screenResolution × 1.35` (`QUALITY_MARGIN`) instead of exact screen resolution, gated by `hasMemoryHeadroomForMargin()` (skips the margin — falls back to the previous exact-resolution behavior — when `ActivityManager.MemoryInfo.lowMemory` is true or `memoryClass < 128`). The sample-size loop still only ever downsamples, never upscales past the source.

## 22. 4K/original strategy

Source assets are never re-encoded by the app; Flutter downloads `fullUrl` (or the depth background plate) at apply time regardless of feed-thumbnail decode caps. The new margin is purely a native decode-target change — no new download/storage behavior.

## 23. Caching

Unchanged Hive-backed `TimedCache` pattern in `ExploreRepositoryImpl`; `getNewWallpapers` reuses the previously-reserved-but-unused `StorageKeys.cacheLatest` slot via the same `_cachedWallpaperPage` helper every other Explore fetch already used.

## 24. Performance safeguards

All preserved: `CustomScrollView`/`SliverMasonryGrid` (never `SingleChildScrollView`+`Column`), bounded image decoding via `WallpaperCard`'s existing `memCacheWidth/Height` math, `LivePreviewPlaybackGate` scroll pause/resume, the 1-concurrent-decoder cap, route-settled Live Details init (`_transitionSettled`), banner slot keying to survive list-shape changes.

## 25. Dead code removed

See §3 for the full list. `injection.dart` lost `_registerClock`/`_registerDepth`/`_registerViewAll` and their imports; gained `_registerCategories`. Stale doc comments referencing `DepthCustomizeView`/`CustomizePage`/`ClockRepository` in `clock_painter.dart`, `clock_renderer_widget.dart`, `depth_layer_stack.dart`, `wallpaper_entity.dart` were reworded to describe the underlying mechanism without naming deleted classes.

## 26. Validation results

- `flutter analyze`: clean throughout every phase, and at the end.
- `flutter test`: 274 tests passing (down from the pre-redesign 348 — 13 files covering ~74 tests deleted as genuinely obsolete; 4 new files added: `explore_bloc_refresh_test.dart` rewritten for the new pagination shape, `bottom_nav_four_tabs_test.dart`, `settings_rows_test.dart`, `apply_sheet_preview_image_test.dart`).
- `flutter build apk --release`: succeeds, 78.4MB.
- `flutter build appbundle --release`: succeeds, 63.2MB.
- Manual on-device pass (Android emulator, release APK installed fresh): confirmed Explore's greeting→search→Transparent card→"New Wallpapers" (no View All)→mixed feed with correct Normal/Depth/Live/PRO badges; Categories tab showing real counts (Nature 9, AMOLED 6, Space 5, Cars 7, Anime 7…); Category Details header + mixed grid; Settings' exact 6 rows in order with no Premium row and the corrected gear icon; Wallpaper Details with no Customize CTA anywhere; Live Details' Play/Pause button beside Apply (confirmed the icon and the actual video both toggle on tap); Apply sheet's new preview thumbnail above "Apply to…". Not verified on-device in this pass: RTL/Arabic layout, fast-scroll/direction-reversal decoder-cap stress test, and rapid two-nearby-Live-cards contention — these rely on the same pre-existing, unmodified `_ActiveVideoRegistry`/`LivePreviewPlaybackGate` mechanisms already covered by the retained decoder-churn test suite, but a fresh physical-device pass is recommended before shipping given how much of Explore's structure changed around them.
