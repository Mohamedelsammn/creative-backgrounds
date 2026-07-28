# Creative Backgrounds — Engineering Tasks
**Version:** 1.0  
**Platform:** Android (Flutter + Native Kotlin)  
**Reference:** implementation_plan.md  
**Date:** 2026-07-13

---

## Implementation Phases Overview

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Project Bootstrap | Scaffolding, tooling, configuration |
| 1 | Core Infrastructure | Network, storage, theme, routing, DI |
| 2 | Design System | Shared widgets, typography, colors, animations |
| 3 | Splash | App initialization flow |
| 4 | Explore Screen | Home discovery surface |
| 5 | Search | Full-text wallpaper search |
| 6 | View All | Paginated grid with filter + sort |
| 7 | Wallpaper Details | Full-screen preview + actions |
| 8 | Favorites | Favorites grid screen |
| 9 | Settings | Language, toggles, cache, about |
| 10 | Clock Engine (Flutter) | ClockPainter, ClockRendererWidget, ClockBloc |
| 11 | Customize Screen | Full editor UI (Clock + Styles + Depth tabs) |
| 12 | Depth Engine (Flutter) | Depth layering, preview, DepthBloc |
| 13 | Native Android — Wallpaper Apply | WallpaperApplyService, WallpaperChannel |
| 14 | Native Android — Live Wallpaper | LiveWallpaperService, ClockRenderer.kt |
| 15 | Native Android — Depth Compositor | DepthCompositor.kt |
| 16 | Apply Flow + Success Screen | Apply bottom sheet, progress, success |
| 17 | About / Privacy / Terms | Static content screens |
| 18 | Localization | Arabic + English, RTL |
| 19 | Connectivity & Error States | Offline banner, retry logic |
| 20 | Performance & Polish | Animation tuning, accessibility, final QA |

---

## Phase 0 — Project Bootstrap

**Objective:** Create the Flutter project with all dependencies configured, Android setup complete, and CI/CD structure in place.

---

### TASK-001 — Create Flutter Project

**Feature:** Project Setup  
**Files:**
- `pubspec.yaml`
- `lib/main.dart`
- `lib/app.dart`
- `android/app/build.gradle`

**Dependencies:** None  
**Description:**  
Create Flutter project targeting Android only. Configure `pubspec.yaml` with all required packages. Set Android `minSdkVersion` to 29 (Android 10+), `targetSdkVersion` to 34.

**Required pubspec.yaml packages:**
```
flutter_bloc: ^8.x
get_it: ^7.x
dio: ^5.x
freezed: ^2.x
json_serializable: ^6.x
freezed_annotation: ^2.x
json_annotation: ^4.x
go_router: ^13.x
cached_network_image: ^3.x
hive: ^2.x
hive_flutter: ^1.x
connectivity_plus: ^5.x
flutter_dotenv: ^5.x
dartz: ^0.10.x
intl: ^0.19.x
equatable: ^2.x
rxdart: ^0.27.x

dev_dependencies:
build_runner
freezed
json_serializable
flutter_lints
```

**Acceptance Criteria:**
- `flutter pub get` runs without error
- `flutter run` boots on Android emulator
- `flutter analyze` returns zero errors

**Estimated Complexity:** Low

---

### TASK-002 — Configure .env and AppConfig

**Feature:** Environment Configuration  
**Files:**
- `.env`
- `.env.example`
- `lib/core/config/app_config.dart`

**Dependencies:** TASK-001  
**Description:**  
Create `.env` file with all placeholder variables from the Environment Variables section of the implementation plan. Create `AppConfig` class that reads values via `flutter_dotenv`. Add `.env` to `pubspec.yaml` assets. Add `.env` to `.gitignore`.

**Acceptance Criteria:**
- All env vars accessible via `AppConfig.baseUrl` etc.
- `.env` is not committed to version control
- `.env.example` is committed with placeholder values only

**Estimated Complexity:** Low

---

### TASK-003 — Configure Folder Structure

**Feature:** Architecture Scaffold  
**Files:**
- All empty placeholder files and directories per the folder structure in implementation_plan.md §3

**Dependencies:** TASK-001  
**Description:**  
Create all directories and placeholder `.dart` files matching the feature-first folder structure. Each feature folder gets `data/`, `domain/`, `presentation/` subdirectories.

**Acceptance Criteria:**
- All directories exist
- Project compiles with empty files

**Estimated Complexity:** Low

---

### TASK-004 — Configure Android Manifest

**Feature:** Android Setup  
**Files:**
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/live_wallpaper.xml`
- `android/app/src/main/res/xml/live_wallpaper_preview.xml`

**Dependencies:** TASK-001  
**Description:**  
Add all required permissions from §15. Register `LiveWallpaperService` with correct `intent-filter` and `meta-data`. Register `MainActivity`. Enable `android:enableOnBackInvokedCallback="true"` for Android 13+ back gesture.

**Acceptance Criteria:**
- Manifest validates with no errors
- App installs and launches on Android 10+ device

**Estimated Complexity:** Low

---

## Phase 1 — Core Infrastructure

**Objective:** Network client, local storage, error handling, DI, routing all wired up but empty.

---

### TASK-005 — Implement DioClient

**Feature:** Networking  
**Files:**
- `lib/core/network/dio_client.dart`
- `lib/core/network/api_interceptor.dart`

**Dependencies:** TASK-002  
**Description:**  
Create `DioClient` singleton that configures `Dio` with:
- `BaseOptions`: baseUrl from `AppConfig`, connect/receive timeouts
- `ApiInterceptor`: adds `Authorization: Bearer {API_KEY}` header to every request, logs request/response when `AppConfig.loggingEnabled`, maps `DioException` types to domain `Failure` subclasses

**Failure types to map:**
- `connectionTimeout` / `receiveTimeout` → `NetworkTimeoutFailure`
- `connectionError` → `NoInternetFailure`
- `badResponse 401` → `UnauthorizedFailure`
- `badResponse 404` → `NotFoundFailure`
- `badResponse 500` → `ServerFailure`
- fallthrough → `UnknownFailure`

**Acceptance Criteria:**
- `DioClient` registered in GetIt
- Interceptor adds auth header on every request
- All DioException types map to typed Failures
- Logging respects `LOGGING_ENABLED` env flag

**Estimated Complexity:** Medium

---

### TASK-006 — Implement Failures & Exceptions

**Feature:** Error Handling  
**Files:**
- `lib/core/error/failures.dart`
- `lib/core/error/exceptions.dart`
- `lib/core/error/error_handler.dart`

**Dependencies:** TASK-001  
**Description:**  
Define abstract `Failure` class with `message` field. Create concrete subclasses: `NetworkTimeoutFailure`, `NoInternetFailure`, `UnauthorizedFailure`, `NotFoundFailure`, `ServerFailure`, `UnknownFailure`, `CacheFailure`, `WallpaperApplyFailure`, `DepthNotSupportedFailure`. All extend `Equatable`.

**Acceptance Criteria:**
- All failure types defined and equatable
- `ErrorHandler.mapFailureToMessage(Failure)` returns locale-aware user-facing string

**Estimated Complexity:** Low

---

### TASK-007 — Initialize Hive Storage

**Feature:** Local Storage  
**Files:**
- `lib/core/storage/hive_storage.dart`
- `lib/core/storage/storage_keys.dart`

**Dependencies:** TASK-001  
**Description:**  
Create `HiveStorage` class that wraps Hive box access. Initialize Hive in `main.dart` before `runApp`. Open boxes: `settings`, `clock_config`, `favorites`, `recent_wallpapers`, `search_history`, `cache_metadata`.

```dart
// main.dart initialization order:
await dotenv.load();
await Hive.initFlutter();
await HiveStorage.init();  // opens all boxes
setupDI();                 // GetIt registration
runApp(const App());
```

**Acceptance Criteria:**
- All Hive boxes open on cold start
- `HiveStorage.read(box, key)` and `write(box, key, value)` work correctly
- No type adapter registration errors

**Estimated Complexity:** Low

---

### TASK-008 — Implement ConnectivityBloc

**Feature:** Connectivity  
**Files:**
- `lib/features/connectivity/bloc/connectivity_bloc.dart`

**Dependencies:** TASK-001, TASK-006  
**Description:**  
Create `ConnectivityBloc` that subscribes to `connectivity_plus` stream. Emits `ConnectivityOnline` / `ConnectivityOffline`. Provide at app root level above router so all screens can listen.

**Acceptance Criteria:**
- Bloc emits correct states when network toggles
- Can be listened to anywhere below the root BlocProvider

**Estimated Complexity:** Low

---

### TASK-009 — Implement GoRouter Navigation

**Feature:** Navigation  
**Files:**
- `lib/core/router/app_router.dart`
- `lib/core/router/route_names.dart`

**Dependencies:** TASK-003  
**Description:**  
Configure GoRouter with the full route tree from implementation_plan.md §7. Set up:
- Root route `/` → `SplashPage`
- Shell route with `FloatingBottomNav` wrapping `/explore`, `/favorites`, `/settings`
- Push routes: `/view-all/:section`, `/wallpaper/:id`, `/customize/:wallpaperId`
- Static routes: `/about`, `/privacy`, `/terms`
- Error page for unknown routes

**Acceptance Criteria:**
- All routes navigate correctly
- Shell route preserves bottom nav across tab switches
- Route parameters accessible via `GoRouterState`
- Deep link to `/wallpaper/:id` works

**Estimated Complexity:** Medium

---

### TASK-010 — Configure GetIt Dependency Injection

**Feature:** DI  
**Files:**
- `lib/injection.dart`

**Dependencies:** TASK-005, TASK-007  
**Description:**  
Create `setupDI()` function called in `main.dart`. Register all singletons, lazy singletons, and factories per implementation_plan.md §13. Use `GetIt.instance` with `registerSingleton`, `registerLazySingleton`, `registerFactory`.

**Acceptance Criteria:**
- All dependencies resolve without circular dependency errors
- `GetIt.I<ExploreBloc>()` returns a fresh Bloc instance each call (factory)
- `GetIt.I<DioClient>()` returns the same instance every call (singleton)

**Estimated Complexity:** Medium

---

## Phase 2 — Design System

**Objective:** All shared visual tokens and reusable widgets implemented before feature screens begin.

---

### TASK-011 — Implement Theme Tokens

**Feature:** Design System  
**Files:**
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/theme/app_shapes.dart`
- `lib/core/theme/app_theme.dart`

**Dependencies:** TASK-001  
**Description:**  
Implement all design tokens from implementation_plan.md §2.1. `AppTheme.lightTheme()` returns `ThemeData` with correct colors, text theme, and shape theme. All values match UI audit observations exactly.

**Font loading:** Add Inter to `pubspec.yaml` assets (Google Fonts or bundled). Add Cormorant/Playfair Display for Elegant clock style. Add JetBrains Mono for Digital clock style.

**Acceptance Criteria:**
- `MaterialApp.theme` uses `AppTheme.lightTheme()`
- All color tokens match the UI audit
- Inter font renders on all text by default
- Clock style fonts load without error

**Estimated Complexity:** Low

---

### TASK-012 — Implement AppSearchBar Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/app_search_bar.dart`

**Dependencies:** TASK-011  
**Description:**  
Pill-shaped search bar. White background, 48dp height, rounded 999dp, left search icon, placeholder "Search wallpapers…", tap action callback (`onTap`), optional `onChanged` for active search mode, `enabled` parameter.

**Acceptance Criteria:**
- Matches design exactly (pill shape, icon, placeholder)
- Tap navigates or activates correctly depending on usage context
- Keyboard dismisses correctly on Android back

**Estimated Complexity:** Low

---

### TASK-013 — Implement FloatingBottomNav Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/floating_bottom_nav.dart`

**Dependencies:** TASK-011  
**Description:**  
Pill-shaped bottom navigation bar. White background with elevation shadow. Three icon buttons: compass (index 0), heart (index 1), sun/brightness (index 2). Active item has filled black circular background (~36dp) around icon. Responds to `currentIndex` and `onTap(index)`. Animated appear/disappear via `AnimatedOpacity` + `AnimatedSlide`.

**Acceptance Criteria:**
- Matches design exactly
- Active state correctly applied to selected tab
- Appears/disappears smoothly based on scroll
- Accessible: each icon has semantic label

**Estimated Complexity:** Medium

---

### TASK-014 — Implement WallpaperCard Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/wallpaper_card.dart`

**Dependencies:** TASK-011  
**Description:**  
Reusable card for carousel and grid use. Accepts: `imageUrl`, `title`, `category`, `isPremium` bool, `onTap`, `heroTag`. Features: `CachedNetworkImage` fill, dark gradient overlay at bottom, title text bottom-left, category text below title, optional PRO badge top-right. Rounded 16dp corners. Hero widget wraps the image.

**Variants:**
- Carousel card: ~280×350dp portrait
- Grid card: fills column width, ~200dp height (or equal-height grid)

**Acceptance Criteria:**
- PRO badge appears when `isPremium = true`
- Hero transition works between card and details screen
- Gradient overlay ensures text legibility on all wallpaper colors
- `CachedNetworkImage` placeholder is a shimmer or gray container

**Estimated Complexity:** Medium

---

### TASK-015 — Implement SectionHeader Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/section_header.dart`

**Dependencies:** TASK-011  
**Description:**  
Row widget with section label on left (semibold, 18sp) and "View All ›" text button on right. `onViewAll` callback parameter.

**Acceptance Criteria:**
- Label and action render correctly
- View All tap fires callback
- Matches design spacing

**Estimated Complexity:** Low

---

### TASK-016 — Implement Loading Shimmer Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/loading_shimmer.dart`

**Dependencies:** TASK-011  
**Description:**  
Animated shimmer placeholder for cards during loading. Use `shimmer` package or implement with `LinearGradient` + `AnimationController`. Accepts `width` and `height` parameters. Rounded corners matching card radius.

**Acceptance Criteria:**
- Shimmer animation runs during loading states
- Correct size matches card placeholder

**Estimated Complexity:** Low

---

### TASK-017 — Implement ErrorView and EmptyStateView Widgets

**Feature:** Design System  
**Files:**
- `lib/core/widgets/error_view.dart`
- `lib/core/widgets/empty_state_view.dart`

**Dependencies:** TASK-011  
**Description:**  
`ErrorView`: icon + headline + message + optional retry button. Used across all error states.  
`EmptyStateView`: icon + headline + subtext. Used for empty favorites, empty search results.

**Acceptance Criteria:**
- Error view retry callback works
- Both widgets render correctly in isolation
- Accessible: minimum tap target on retry button

**Estimated Complexity:** Low

---

### TASK-018 — Implement SegmentedControl Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/segmented_control.dart`

**Dependencies:** TASK-011  
**Description:**  
3-segment tab bar used in the Customize screen. Dark frosted pill container. Selected segment has white pill background. `segments: List<String>`, `selectedIndex: int`, `onSegmentChanged(int)`. Animated segment slide via `AnimatedPositioned` or `AnimatedContainer`.

**Acceptance Criteria:**
- Matches design exactly (dark background, white selected pill)
- Animation between segments is smooth 200ms
- Works with 3 segments of varying label widths

**Estimated Complexity:** Medium

---

### TASK-019 — Implement OptionChipRow Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/option_chip_row.dart`

**Dependencies:** TASK-011  
**Description:**  
Horizontal scrollable row of pill chips. `options: List<String>`, `selectedOption: String`, `onSelected(String)`. Selected chip: white fill, black text. Unselected: transparent fill, gray text.

**Acceptance Criteria:**
- Selection updates immediately
- Chips are correctly styled per design
- Used for Position, Font chip rows

**Estimated Complexity:** Low

---

### TASK-020 — Implement ColorSwatchRow Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/color_swatch_row.dart`

**Dependencies:** TASK-011  
**Description:**  
Row of 4 circular color swatches. `colors: List<Color>`, `selectedColor: Color`, `onSelected(Color)`. Selected swatch has a white border ring. Minimum 36dp touch target per swatch.

**Acceptance Criteria:**
- Four swatches render: white, black, gray-blue, warm cream
- Selected state shows white ring
- Accessible touch targets

**Estimated Complexity:** Low

---

### TASK-021 — Implement LabeledSlider Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/labeled_slider.dart`

**Dependencies:** TASK-011  
**Description:**  
Row with label on left, formatted value on right, `Slider` below. `label: String`, `value: double`, `min: double`, `max: double`, `valueSuffix: String` (e.g., "px" or "%"), `onChanged: ValueChanged<double>`.

**Acceptance Criteria:**
- Label + value display correctly
- Slider drag updates value in real time
- Value display formats correctly (76px, 100%)

**Estimated Complexity:** Low

---

### TASK-022 — Implement ToggleRow Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/toggle_row.dart`

**Dependencies:** TASK-011  
**Description:**  
Row with `label` text on left, `Switch` on right. Dark/black active color for switch (matching design). `label: String`, `value: bool`, `onChanged: ValueChanged<bool>`.

**Acceptance Criteria:**
- Toggle matches design (dark active color)
- State updates correctly

**Estimated Complexity:** Low

---

### TASK-023 — Implement SettingsRow Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/settings_row.dart`

**Dependencies:** TASK-011  
**Description:**  
White background row widget. `title: String`, `subtitle: String?`, `trailing: Widget?`. Divider at bottom (except last row). Onion-skin pattern: accepts any trailing widget (toggle, chevron, language pills).

**Acceptance Criteria:**
- Title and subtitle layout match design
- Divider appears correctly
- Trailing widget renders correctly for all Settings rows

**Estimated Complexity:** Low

---

### TASK-024 — Implement BottomSheetHandle Widget

**Feature:** Design System  
**Files:**
- `lib/core/widgets/bottom_sheet_handle.dart`

**Dependencies:** TASK-011  
**Description:**  
Small horizontal pill (36dp × 4dp, gray/semi-transparent) centered at top of draggable panels. `Container` with border-radius.

**Acceptance Criteria:**
- Matches design pill indicator
- Renders at panel top center

**Estimated Complexity:** Low

---

## Phase 3 — Splash Screen

**Objective:** Functional splash with initialization logic.

---

### TASK-025 — Implement SplashBloc

**Feature:** Splash  
**Files:**
- `lib/features/splash/presentation/bloc/splash_bloc.dart`
- `lib/features/splash/domain/usecases/initialize_app_usecase.dart`

**Dependencies:** TASK-010  
**Description:**  
`InitializeAppUseCase` orchestrates: open Hive boxes, load settings, check connectivity, fetch remote config. `SplashBloc` calls this use case on `SplashStarted` event. Emits `SplashLoading` → `SplashComplete` or `SplashError`.

**Acceptance Criteria:**
- All init steps execute in correct order
- Navigates to `/explore` on `SplashComplete` (GoRouter listener)
- Minimum display time: 1500ms even if init completes early

**Estimated Complexity:** Medium

---

### TASK-026 — Implement SplashPage UI

**Feature:** Splash  
**Files:**
- `lib/features/splash/presentation/pages/splash_page.dart`

**Dependencies:** TASK-025, TASK-011  
**Description:**  
Full-screen white background with centered logo/wordmark. `AnimatedOpacity` fade-in from 0→1 over 600ms. `BlocListener` on `SplashBloc`: on `SplashComplete` → `context.go('/explore')`. On `SplashError` → show error dialog with retry.

**Acceptance Criteria:**
- Logo animates in correctly
- Navigation to Explore happens after init
- Error case shows actionable message

**Estimated Complexity:** Low

---

## Phase 4 — Explore Screen

**Objective:** Full Explore screen with trending, latest, and category carousels.

---

### TASK-027 — Implement Wallpaper & Category Domain Entities

**Feature:** Explore — Domain  
**Files:**
- `lib/features/explore/domain/entities/wallpaper_entity.dart`
- `lib/features/explore/domain/entities/category_entity.dart`
- `lib/features/explore/domain/repositories/explore_repository.dart`

**Dependencies:** TASK-006  
**Description:**  
Define `WallpaperEntity` with all fields from API response spec: `id`, `title`, `category`, `thumbnailUrl`, `fullUrl`, `resolution`, `isPremium`, `hasForegroundMask`, `foregroundMaskUrl`, `downloadCount`, `createdAt`. Define `CategoryEntity`: `id`, `name`, `thumbnailUrl`, `wallpaperCount`, `color`. All entities extend `Equatable`. Define `ExploreRepository` interface with methods: `getTrending(page)`, `getLatest(page)`, `getCategories()`.

**Acceptance Criteria:**
- Entities compile and are equatable
- Repository interface defines all required methods returning `Future<Either<Failure, T>>`

**Estimated Complexity:** Low

---

### TASK-028 — Implement Wallpaper & Category Models (Freezed)

**Feature:** Explore — Data  
**Files:**
- `lib/features/explore/data/models/wallpaper_model.dart`
- `lib/features/explore/data/models/category_model.dart`

**Dependencies:** TASK-027  
**Description:**  
Create `WallpaperModel` and `CategoryModel` using `@freezed` annotation. Each model has `fromJson` factory (via `@JsonSerializable`). Run `build_runner` to generate `.freezed.dart` and `.g.dart` files. Models should implement or map to their entity counterparts.

**Acceptance Criteria:**
- `WallpaperModel.fromJson({...})` parses all API fields correctly
- `build_runner` generates without errors
- Null fields (e.g., `foregroundMaskUrl`) handled correctly

**Estimated Complexity:** Low

---

### TASK-029 — Implement ExploreRemoteDatasource

**Feature:** Explore — Data  
**Files:**
- `lib/features/explore/data/datasources/explore_remote_datasource.dart`

**Dependencies:** TASK-005, TASK-028  
**Description:**  
`ExploreRemoteDatasource` with abstract interface and `ExploreRemoteDatasourceImpl` using `DioClient`. Methods: `getTrending({int page, int limit})`, `getLatest({int page, int limit})`, `getCategories()`. Each method calls the corresponding API endpoint and returns parsed `List<WallpaperModel>` or `List<CategoryModel>`. Throws typed exceptions on network errors.

**Acceptance Criteria:**
- Each method makes the correct API call
- Response is parsed to correct model types
- HTTP errors throw typed exceptions

**Estimated Complexity:** Medium

---

### TASK-030 — Implement ExploreRepositoryImpl

**Feature:** Explore — Data  
**Files:**
- `lib/features/explore/data/repositories/explore_repository_impl.dart`

**Dependencies:** TASK-007, TASK-029  
**Description:**  
Implements `ExploreRepository`. Each method:
1. Try to read from Hive cache (if cache valid, return cached)
2. If no cache or stale: call remote datasource
3. On success: write to Hive cache with timestamp
4. Return `Right(data)` on success, `Left(Failure)` on error
5. Cache TTL: trending 30 min, latest 30 min, categories 24h

**Acceptance Criteria:**
- Returns cached data when available and fresh
- Fetches from network when cache is stale or empty
- All error paths return typed `Left(Failure)`

**Estimated Complexity:** Medium

---

### TASK-031 — Implement Explore Use Cases

**Feature:** Explore — Domain  
**Files:**
- `lib/features/explore/domain/usecases/get_trending_wallpapers_usecase.dart`
- `lib/features/explore/domain/usecases/get_latest_wallpapers_usecase.dart`
- `lib/features/explore/domain/usecases/get_categories_usecase.dart`

**Dependencies:** TASK-027  
**Description:**  
Single-method use cases following the `call()` pattern. `GetTrendingWallpapersUseCase(ExploreRepository)` calls `repository.getTrending(page: params.page)`.

**Acceptance Criteria:**
- Each use case calls the correct repository method
- Returns `Future<Either<Failure, T>>`

**Estimated Complexity:** Low

---

### TASK-032 — Implement ExploreBloc

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/bloc/explore_bloc.dart`
- `lib/features/explore/presentation/bloc/explore_event.dart`
- `lib/features/explore/presentation/bloc/explore_state.dart`

**Dependencies:** TASK-031  
**Description:**  
`ExploreBloc` receives `ExploreStarted` event. Emits `ExploreLoading`. Fires parallel futures for trending, latest, categories using `Future.wait`. On all success: emits `ExploreLoaded`. On any failure: emits `ExploreError`. Handle `ExploreRefreshRequested` to re-fetch all sections.

**Acceptance Criteria:**
- All three sections load in parallel
- Any single failure shows error state
- Refresh clears and reloads all sections

**Estimated Complexity:** Medium

---

### TASK-033 — Implement GreetingHeader Widget

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/widgets/greeting_header.dart`

**Dependencies:** TASK-011  
**Description:**  
Displays "GOOD MORNING / GOOD AFTERNOON / GOOD EVENING" based on current hour (morning: 5–11, afternoon: 12–17, evening: 18–4), and "Discover Wallpapers" headline below. Use `DateTime.now().hour` at build time.

**Acceptance Criteria:**
- Correct greeting for each time range
- Typography matches design (overline + display)

**Estimated Complexity:** Low

---

### TASK-034 — Implement TrendingCarousel Widget

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/widgets/trending_carousel.dart`

**Dependencies:** TASK-014, TASK-015  
**Description:**  
Horizontal `PageView` or `ListView` with peek effect (partial cards visible at left and right edges). Center card is slightly scaled up (1.0) vs side cards (0.95) for a snap-carousel feel. Each card: `WallpaperCard`. Tap navigates to `/wallpaper/:id`.

**Acceptance Criteria:**
- Peek cards visible at both edges
- Center card slightly scaled
- Smooth horizontal scrolling
- PRO badge on premium wallpapers

**Estimated Complexity:** Medium

---

### TASK-035 — Implement LatestCarousel Widget

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/widgets/latest_carousel.dart`

**Dependencies:** TASK-014, TASK-015  
**Description:**  
Same structure as `TrendingCarousel` but for the Latest section. Cards slightly different aspect ratio if needed. Tap navigates to wallpaper details.

**Acceptance Criteria:**
- Same carousel behavior as trending
- Aurora, Void, and other latest wallpapers display correctly

**Estimated Complexity:** Medium

---

### TASK-036 — Implement CategoryCarousel Widget

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/widgets/category_carousel.dart`

**Dependencies:** TASK-014, TASK-015  
**Description:**  
Horizontal carousel for a single category section (e.g., "Nature"). Reuses `WallpaperCard`. Generates one `SectionHeader` + one carousel per category returned by API. Dynamic: if API returns 5 categories, 5 sections render.

**Acceptance Criteria:**
- Dynamic category sections render from API data
- Each section has correct name and "View All" link
- Tap on "View All" navigates to `/view-all/{categoryId}`

**Estimated Complexity:** Medium

---

### TASK-037 — Implement ExplorePage

**Feature:** Explore — Presentation  
**Files:**
- `lib/features/explore/presentation/pages/explore_page.dart`

**Dependencies:** TASK-032, TASK-033, TASK-034, TASK-035, TASK-036, TASK-013  
**Description:**  
`SingleChildScrollView` (or `CustomScrollView` with Slivers) containing: greeting header, search bar, trending section, latest section, dynamic category sections. `BlocProvider<ExploreBloc>` wraps the page. `BlocBuilder` handles loading/loaded/error states. Pull-to-refresh via `RefreshIndicator`. `ScrollController` listener shows `FloatingBottomNav` after 100dp scroll.

**Acceptance Criteria:**
- All sections load and display correctly
- Pull-to-refresh triggers `ExploreRefreshRequested`
- FloatingBottomNav appears on scroll
- Loading state shows shimmer cards
- Error state shows `ErrorView` with retry

**Estimated Complexity:** High

---

## Phase 5 — Search Screen

---

### TASK-038 — Implement Search Domain Layer

**Feature:** Search  
**Files:**
- `lib/features/search/domain/repositories/search_repository.dart`
- `lib/features/search/domain/usecases/search_wallpapers_usecase.dart`
- `lib/features/search/data/datasources/search_remote_datasource.dart`
- `lib/features/search/data/repositories/search_repository_impl.dart`

**Dependencies:** TASK-027  
**Description:**  
`SearchRepository` interface with `search(query, page)` method. `SearchRemoteDatasource` calls `GET /wallpapers/search?q={query}&page={page}`. `SearchRepositoryImpl` calls datasource and returns `Either<Failure, List<WallpaperEntity>>`.

**Acceptance Criteria:**
- Correct endpoint called with correct params
- Results parsed as `WallpaperEntity` list

**Estimated Complexity:** Medium

---

### TASK-039 — Implement SearchBloc

**Feature:** Search  
**Files:**
- `lib/features/search/presentation/bloc/search_bloc.dart`

**Dependencies:** TASK-038  
**Description:**  
Handles `SearchQueryChanged(query)` with 300ms debounce using `rxdart` or `EventTransformer`. Cancels prior requests. Emits `SearchInitial` on empty query, `SearchLoading` on debounce, `SearchLoaded(results)`, `SearchEmpty`, or `SearchError`. Handles `SearchLoadMoreRequested` for pagination. Saves queries to Hive `search_history` box.

**Acceptance Criteria:**
- 300ms debounce on query change
- Prior request cancelled on new query
- Search history saved on successful search
- Empty query returns `SearchInitial` showing history

**Estimated Complexity:** Medium

---

### TASK-040 — Implement SearchPage

**Feature:** Search  
**Files:**
- `lib/features/search/presentation/pages/search_page.dart`

**Dependencies:** TASK-039, TASK-012, TASK-014  
**Description:**  
Full-screen search page. AppBar with back button + active `AppSearchBar`. `BlocBuilder` on `SearchBloc`. States: initial → show recent searches as chips; loading → shimmer grid; loaded → wallpaper grid; empty → `EmptyStateView`; error → `ErrorView`. Keyboard shows immediately on page enter (`autofocus: true`). Recent search chips clear with a clear button.

**Acceptance Criteria:**
- Autofocus keyboard on enter
- Search results match query
- Recent searches appear on empty query
- Infinite scroll loads more results

**Estimated Complexity:** Medium

---

## Phase 6 — View All Screen

---

### TASK-041 — Implement ViewAll Domain Layer

**Feature:** View All  
**Files:**
- `lib/features/view_all/domain/repositories/view_all_repository.dart`
- `lib/features/view_all/domain/usecases/get_section_wallpapers_usecase.dart`
- `lib/features/view_all/data/datasources/view_all_remote_datasource.dart`
- `lib/features/view_all/data/repositories/view_all_repository_impl.dart`

**Dependencies:** TASK-027  
**Description:**  
Repository interface `getSectionWallpapers(section, page, filter?, sort?)`. Datasource calls appropriate endpoint (`/wallpapers/trending`, `/wallpapers/latest`, `/wallpapers`, `/categories/:id/wallpapers`) based on `section` parameter. Supports `FilterOptions` (categories, orientation) and `SortOption` (trending, latest, downloads, alphabetical) query params.

**Acceptance Criteria:**
- Correct endpoint called per section
- Filter and sort params included in request
- Pagination works

**Estimated Complexity:** Medium

---

### TASK-042 — Implement ViewAllBloc

**Feature:** View All  
**Files:**
- `lib/features/view_all/presentation/bloc/view_all_bloc.dart`

**Dependencies:** TASK-041  
**Description:**  
Handles initial fetch, load more (pagination), filter changes, sort changes. On `ViewAllFilterApplied` or `ViewAllSortApplied`: reset to page 1, re-fetch. On `ViewAllLoadMoreRequested`: append results to existing list.

**Acceptance Criteria:**
- Pagination appends correctly (no duplicates)
- Filter and sort reset pagination
- `hasMore: false` stops pagination trigger

**Estimated Complexity:** Medium

---

### TASK-043 — Implement WallpaperGrid Widget

**Feature:** View All  
**Files:**
- `lib/features/view_all/presentation/widgets/wallpaper_grid.dart`

**Dependencies:** TASK-014  
**Description:**  
2-column `GridView` (or `GridView.builder`) with 8dp spacing. Equal-height cells. Each cell is a `WallpaperCard`. Bottom loading indicator when `hasMore` is true. Triggers `ViewAllLoadMoreRequested` when user scrolls within 200dp of bottom.

**Acceptance Criteria:**
- 2-column grid with correct spacing
- Infinite scroll triggers correctly
- Loading indicator appears at bottom during pagination
- Cards match View All screen design (title + category color overlay)

**Estimated Complexity:** Medium

---

### TASK-044 — Implement Filter and Sort Bottom Sheets

**Feature:** View All  
**Files:**
- `lib/features/view_all/presentation/widgets/filter_bottom_sheet.dart`
- `lib/features/view_all/presentation/widgets/sort_bottom_sheet.dart`

**Dependencies:** TASK-011  
**Description:**  
`FilterBottomSheet`: shows category checkboxes, orientation radio buttons. "Apply" primary button + "Reset" text button.  
`SortBottomSheet`: radio list with Trending, Latest, Most Downloaded, Alphabetical options. Selection closes sheet and applies sort.

**Acceptance Criteria:**
- Filter selections persist during session
- Apply fires `ViewAllFilterApplied`
- Sort selection fires `ViewAllSortApplied`
- Bottom sheet drag handle present

**Estimated Complexity:** Medium

---

### TASK-045 — Implement ViewAllPage

**Feature:** View All  
**Files:**
- `lib/features/view_all/presentation/pages/view_all_page.dart`

**Dependencies:** TASK-042, TASK-043, TASK-044, TASK-012  
**Description:**  
Page layout: back button + search bar in header; section title + filter/sort chips row; wallpaper grid below. Section title reads "Trending", "Latest", "All", or category name from route param. Tapping filter/sort chips opens respective bottom sheets.

**Acceptance Criteria:**
- Section title matches route param
- Filters and sort chips show active state when applied
- Grid renders correctly
- Back navigates to Explore

**Estimated Complexity:** Medium

---

## Phase 7 — Wallpaper Details Screen

---

### TASK-046 — Implement WallpaperDetails Domain Layer

**Feature:** Wallpaper Details  
**Files:**
- `lib/features/wallpaper_details/domain/repositories/wallpaper_details_repository.dart`
- `lib/features/wallpaper_details/domain/usecases/get_wallpaper_details_usecase.dart`
- `lib/features/wallpaper_details/data/datasources/wallpaper_details_remote_datasource.dart`
- `lib/features/wallpaper_details/data/repositories/wallpaper_details_repository_impl.dart`

**Dependencies:** TASK-027  
**Description:**  
`GetWallpaperDetailsUseCase` calls `GET /wallpapers/:id`. Returns full `WallpaperEntity` including depth fields. Repository also integrates with `FavoritesRepository` to check if wallpaper is favorited locally.

**Acceptance Criteria:**
- Full wallpaper detail returned from API
- `isFavorite` flag derived from local Hive favorites box

**Estimated Complexity:** Medium

---

### TASK-047 — Implement WallpaperDetailsBloc

**Feature:** Wallpaper Details  
**Files:**
- `lib/features/wallpaper_details/presentation/bloc/wallpaper_details_bloc.dart`

**Dependencies:** TASK-046  
**Description:**  
Handles `WallpaperDetailsFetchRequested(id)`, `WallpaperFavoriteToggleRequested`, `WallpaperShareRequested`. On favorite toggle: calls `AddFavoriteUseCase` or `RemoveFavoriteUseCase` and emits updated `isFavorite` state. On share: triggers system share sheet via `share_plus` package.

**Acceptance Criteria:**
- Details load from API
- Favorite toggle updates local Hive immediately (optimistic update)
- Favorite toggle also calls API if user is authenticated
- Share opens system share sheet with wallpaper URL

**Estimated Complexity:** Medium

---

### TASK-048 — Implement WallpaperInfoPanel Widget

**Feature:** Wallpaper Details  
**Files:**
- `lib/features/wallpaper_details/presentation/widgets/wallpaper_info_panel.dart`

**Dependencies:** TASK-011  
**Description:**  
Dark semi-transparent bottom panel (rounded top 24dp). Contains: wallpaper name (bold white 22sp), category + resolution (gray secondary). Two buttons: "Customize" (white fill, sparkle icon) and "Apply" (black fill, white text). Buttons are side-by-side, equal width. Panel uses `ClipRRect` + `BackdropFilter` for blur effect.

**Acceptance Criteria:**
- Panel matches design exactly
- Customize button navigates to `/customize/:id`
- Apply button opens apply destination bottom sheet
- Blur effect renders on Android

**Estimated Complexity:** Medium

---

### TASK-049 — Implement WallpaperDetailsPage

**Feature:** Wallpaper Details  
**Files:**
- `lib/features/wallpaper_details/presentation/pages/wallpaper_details_page.dart`

**Dependencies:** TASK-047, TASK-048  
**Description:**  
Full-bleed image page. Stack: `CachedNetworkImage` (full size, edge to edge, extends behind system bars). Hero widget on image. Top overlay: back button + heart + share buttons (circular frosted glass). Bottom: `WallpaperInfoPanel`. `BlocBuilder`: loading → full-screen shimmer; loaded → image + panel; error → error overlay. Edge-to-edge: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` on page enter, restore on exit.

**Acceptance Criteria:**
- Image extends full screen including behind system bars
- Hero transition from card works smoothly
- All three action buttons (back, heart, share) function
- Heart fills on favorite tap with spring animation
- Info panel overlaid at bottom with blur

**Estimated Complexity:** High

---

## Phase 8 — Favorites Screen

---

### TASK-050 — Implement Favorites Domain Layer

**Feature:** Favorites  
**Files:**
- `lib/features/favorites/domain/repositories/favorites_repository.dart`
- `lib/features/favorites/domain/usecases/get_favorites_usecase.dart`
- `lib/features/favorites/domain/usecases/add_favorite_usecase.dart`
- `lib/features/favorites/domain/usecases/remove_favorite_usecase.dart`
- `lib/features/favorites/data/datasources/favorites_local_datasource.dart`
- `lib/features/favorites/data/repositories/favorites_repository_impl.dart`

**Dependencies:** TASK-007, TASK-027  
**Description:**  
Favorites are stored locally in Hive. `FavoritesLocalDatasource` reads/writes to `favorites` box using wallpaperId as key and serialized `WallpaperEntity` JSON as value. `FavoritesRepositoryImpl` wraps local datasource. No remote sync required for V1 (per design — no login/account visible in screens).

**Acceptance Criteria:**
- Favorites persist across app restarts
- `GetFavoritesUseCase` returns all saved wallpapers
- `AddFavoriteUseCase` saves wallpaper to Hive
- `RemoveFavoriteUseCase` removes by ID

**Estimated Complexity:** Medium

---

### TASK-051 — Implement FavoritesBloc

**Feature:** Favorites  
**Files:**
- `lib/features/favorites/presentation/bloc/favorites_bloc.dart`

**Dependencies:** TASK-050  
**Description:**  
Loads favorites on `FavoritesFetchRequested`. Handles `FavoriteRemovedRequested(id)` (long-press or swipe on grid item). Emits `FavoritesLoaded`, `FavoritesEmpty`, `FavoritesError`.

**Acceptance Criteria:**
- Favorites list updates when favorite is added/removed from WallpaperDetails screen (via `FavoriteAddedRequested` cross-feature event or Hive listener)
- Empty state emits `FavoritesEmpty`

**Estimated Complexity:** Medium

---

### TASK-052 — Implement FavoritesPage

**Feature:** Favorites  
**Files:**
- `lib/features/favorites/presentation/pages/favorites_page.dart`

**Dependencies:** TASK-051, TASK-014, TASK-013  
**Description:**  
Page with "Favorites" large title, 2-column staggered grid (`flutter_staggered_grid_view` or manual). Each card taps to wallpaper details. Long-press or delete icon removes from favorites. `EmptyStateView` when no favorites. `FloatingBottomNav` with heart active.

**Acceptance Criteria:**
- Staggered grid matches design (varying heights)
- Wallpaper name + category overlay on cards
- Empty state renders correctly
- Bottom nav heart icon is active

**Estimated Complexity:** Medium

---

## Phase 9 — Settings Screen

---

### TASK-053 — Implement Settings Domain Layer

**Feature:** Settings  
**Files:**
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/features/settings/domain/usecases/get_settings_usecase.dart`
- `lib/features/settings/domain/usecases/update_settings_usecase.dart`
- `lib/features/settings/data/datasources/settings_local_datasource.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`

**Dependencies:** TASK-007  
**Description:**  
`AppSettings` entity: `language`, `autoChangeWallpaper`, `highQualityDownloads`, `cachedSizeBytes`, `appVersion`. All settings stored in Hive `settings` box. `cachedSizeBytes` is computed dynamically by summing `CachedNetworkImage`'s disk cache size + Hive box sizes.

**Acceptance Criteria:**
- All settings persist across restarts
- Cache size is accurately computed
- Settings load on first run with defaults: language=en, autoChange=false, HQDownloads=true

**Estimated Complexity:** Medium

---

### TASK-054 — Implement SettingsBloc

**Feature:** Settings  
**Files:**
- `lib/features/settings/presentation/bloc/settings_bloc.dart`

**Dependencies:** TASK-053  
**Description:**  
Loads settings on `SettingsLoadRequested`. Handles all update events. `SettingsClearCacheRequested`: clears `CachedNetworkImage.defaultCacheManager()`, clears Hive `cache_metadata` box, recomputes size, emits `SettingsCacheCleared`. `SettingsLanguageChanged`: updates Hive + triggers app locale change via `context.setLocale()` or similar.

**Acceptance Criteria:**
- All toggle events update Hive immediately
- Clear cache refreshes displayed size after clearing
- Language change takes effect immediately without restart

**Estimated Complexity:** Medium

---

### TASK-055 — Implement LanguageToggle Widget

**Feature:** Settings  
**Files:**
- `lib/features/settings/presentation/widgets/language_toggle.dart`

**Dependencies:** TASK-011  
**Description:**  
Two-button toggle: "English" (left) and "العربية" (right). Selected button has black fill, white text. Unselected has white fill, black text. Rounded pill. Calls `onLanguageSelected(String locale)` on tap.

**Acceptance Criteria:**
- Toggle style matches design exactly
- Arabic label renders correctly (RTL text)
- Selection updates instantly

**Estimated Complexity:** Low

---

### TASK-056 — Implement SettingsPage

**Feature:** Settings  
**Files:**
- `lib/features/settings/presentation/pages/settings_page.dart`

**Dependencies:** TASK-054, TASK-055, TASK-023  
**Description:**  
Page with "Settings" large title. Settings rows card with `SettingsRow` for each setting. Language row uses `LanguageToggle` as trailing. Auto-change row uses `Switch`. HQ Downloads row uses `Switch`. Clear cache row uses chevron + dynamic size subtitle. About row uses chevron. Version footer at bottom. `FloatingBottomNav` with sun active.

**Acceptance Criteria:**
- All rows render with correct labels and trailing widgets
- Cache size shown in subtitle (e.g., "42 MB used")
- All toggles and actions work
- Bottom nav sun icon is active

**Estimated Complexity:** Medium

---

### TASK-057 — Implement About / Privacy / Terms Pages

**Feature:** Settings — Static Pages  
**Files:**
- `lib/features/settings/presentation/pages/about_page.dart`
- `lib/features/settings/presentation/pages/privacy_policy_page.dart`
- `lib/features/settings/presentation/pages/terms_page.dart`

**Dependencies:** TASK-011  
**Description:**  
Simple pages with app bar (back button + title). Content: either static `RichText` content or `WebViewWidget` (from `webview_flutter`) loading remote URLs. About page includes app version, developer info, open-source licenses button (which opens `showLicensePage`).

**Acceptance Criteria:**
- Back navigation works
- Content loads (static or webview)
- About shows correct version from `package_info_plus`

**Estimated Complexity:** Low

---

## Phase 10 — Clock Engine (Flutter)

**Objective:** Full clock rendering pipeline in Flutter (for live preview in Customize screen).

---

### TASK-058 — Implement ClockConfig Domain Entity

**Feature:** Clock Engine  
**Files:**
- `lib/features/clock/domain/entities/clock_config_entity.dart`
- `lib/features/clock/data/models/clock_config_model.dart`

**Dependencies:** TASK-001  
**Description:**  
`ClockConfigEntity`: all fields per implementation_plan.md §8.2. `ClockStyle` enum: `modern`, `minimal`, `elegant`, `digital`. `ClockPosition` enum: `top`, `center`, `bottom`. `ClockFont` enum: `inter`, `serif`, `mono`. `ClockConfigModel` uses `@freezed` with `fromJson`/`toJson`. Default config: Inter, center, white, 76px, 100% opacity, shadow on, glow off, stroke off, 12h, date on, seconds off, style=modern.

**Acceptance Criteria:**
- All fields present and typed correctly
- `fromJson`/`toJson` round-trips losslessly
- Default config matches design screenshots

**Estimated Complexity:** Low

---

### TASK-059 — Implement ClockRepository

**Feature:** Clock Engine  
**Files:**
- `lib/features/clock/domain/repositories/clock_repository.dart`
- `lib/features/clock/domain/usecases/save_clock_config_usecase.dart`
- `lib/features/clock/domain/usecases/load_clock_config_usecase.dart`
- `lib/features/clock/data/repositories/clock_repository_impl.dart`

**Dependencies:** TASK-058, TASK-007  
**Description:**  
`ClockRepositoryImpl` reads/writes to Hive `clock_config` box. `LoadClockConfigUseCase` returns saved config or default. `SaveClockConfigUseCase` writes to Hive and calls `ClockChannel.saveClockConfig(config)` to sync with native side.

**Acceptance Criteria:**
- Config survives app restart
- Native side receives config via platform channel

**Estimated Complexity:** Low

---

### TASK-060 — Implement ClockPainter (Flutter CustomPainter)

**Feature:** Clock Engine  
**Files:**
- `lib/features/clock/presentation/widgets/clock_painter.dart`

**Dependencies:** TASK-058  
**Description:**  
`ClockPainter extends CustomPainter` that draws the current time and date string onto the canvas. Implements:

- `_formatTime(DateTime, bool is24Hour, bool showSeconds) → String`: formats as "5:37" or "5:37:00"
- `_formatDate(DateTime) → String`: formats as "Monday, July 13"
- `_drawTime(Canvas, Size, ClockConfig, DateTime)`: uses `TextPainter` with correct `TextStyle` per `ClockConfig.font` and `ClockConfig.style`; positions based on `ClockConfig.position`
- `_drawDate(Canvas, Size, ClockConfig, DateTime)`: drawn below time when `showDate = true`
- `_applyGlow(Paint, ClockConfig)`: adds `MaskFilter.blur(BlurStyle.outer, ...)` when `showGlow = true`
- `_applyShadow(paint, config)`: adds shadow using `canvas.saveLayer` + `Paint.imageFilter`
- `_drawStroke(Canvas, Size, ClockConfig, DateTime)`: draws same text in stroke mode below main text for stroke effect

**Acceptance Criteria:**
- All clock styles render correctly (Modern, Minimal, Elegant, Digital) with correct fonts
- Position (top/center/bottom) correctly places clock on canvas
- Shadow, glow, stroke effects are visually correct
- `shouldRepaint` returns true only when config or time changes

**Estimated Complexity:** High

---

### TASK-061 — Implement ClockRendererWidget

**Feature:** Clock Engine  
**Files:**
- `lib/features/clock/presentation/widgets/clock_renderer_widget.dart`

**Dependencies:** TASK-060  
**Description:**  
`StatefulWidget`. Holds a `Timer.periodic(Duration(seconds: 1))` that calls `setState` to trigger repaint. Uses `CustomPaint(painter: ClockPainter(config: clockConfig, now: _currentTime))`. Accepts `clockConfig: ClockConfig` parameter. `dispose()` cancels the timer.

**Acceptance Criteria:**
- Clock ticks every second
- Updating `clockConfig` (e.g., changing color) immediately reflects in preview
- Timer cancelled when widget disposed (no memory leak)

**Estimated Complexity:** Medium

---

### TASK-062 — Implement ClockBloc

**Feature:** Clock Engine  
**Files:**
- `lib/features/clock/presentation/bloc/clock_bloc.dart`
- `lib/features/clock/presentation/bloc/clock_event.dart`
- `lib/features/clock/presentation/bloc/clock_state.dart`

**Dependencies:** TASK-059  
**Description:**  
Handles all clock configuration events from implementation_plan.md §6.7. On each config change event, emits updated `ClockReady(config)` immediately (no debounce needed — instant preview). On `ClockConfigSaved`, calls `SaveClockConfigUseCase`.

**Acceptance Criteria:**
- Every config change emits new state with updated config
- ClockRendererWidget rebuilds on each state change
- Config is saved to Hive when `ClockConfigSaved` fired

**Estimated Complexity:** Medium

---

## Phase 11 — Customize Screen

---

### TASK-063 — Implement CustomizeBloc

**Feature:** Customize  
**Files:**
- `lib/features/customize/presentation/bloc/customize_bloc.dart`

**Dependencies:** TASK-062  
**Description:**  
Manages the active tab index (Clock=0, Styles=1, Depth=2). Handles `CustomizeTabChanged(tab)`. Handles `CustomizeApplyRequested(destination)` which fires `ApplyWallpaperBloc` or navigates to apply flow.

**Acceptance Criteria:**
- Tab switching correctly changes active tab
- Apply action triggers apply flow

**Estimated Complexity:** Low

---

### TASK-064 — Implement ClockSettingsPanel Widget

**Feature:** Customize  
**Files:**
- `lib/features/customize/presentation/widgets/clock_settings_panel.dart`

**Dependencies:** TASK-019, TASK-020, TASK-021, TASK-022, TASK-062  
**Description:**  
Scrollable column of clock settings controls, all within the dark bottom panel. Sections (in scroll order): Position chip row → Font chip row → Color swatch row → Size slider → Opacity slider → Shadow toggle → Glow toggle → Stroke toggle → 24-Hour toggle → Date toggle → Seconds toggle. Each control dispatches the corresponding `ClockBloc` event on change. Panel background: frosted dark glass (`BackdropFilter`).

**Acceptance Criteria:**
- All controls render in correct order
- Each control updates `ClockBloc` which updates `ClockRendererWidget` preview in real time
- Panel scrolls vertically when content exceeds visible area
- Design labels ("POSITION", "FONT", "COLOR") match exactly

**Estimated Complexity:** High

---

### TASK-065 — Implement ClockStylesPanel Widget

**Feature:** Customize  
**Files:**
- `lib/features/customize/presentation/widgets/clock_styles_panel.dart`
- `lib/features/customize/presentation/widgets/clock_style_card.dart`

**Dependencies:** TASK-060, TASK-018  
**Description:**  
2-column grid of `ClockStyleCard` widgets. `ClockStyleCard`: frosted dark background card (~160dp wide), contains mini clock preview (static "09:41" in the target style font), label below. Selected card: white border ring. Tapping card dispatches `ClockStyleChanged(style)`.

**Acceptance Criteria:**
- All clock styles render with correct fonts
- Selected card has visible white border
- Selection updates live preview in upper portion of screen
- Grid scrolls if more than 4 styles

**Estimated Complexity:** High

---

### TASK-066 — Implement DepthSettingsPanel Widget

**Feature:** Customize  
**Files:**
- `lib/features/customize/presentation/widgets/depth_settings_panel.dart`

**Dependencies:** TASK-022  
**Description:**  
Panel content: "Depth Effect" label + description text + toggle. Inline preview card showing layered wallpaper. Toggle dispatches `DepthEffectToggled`. If `wallpaperSupportsDepth = false`, toggle is disabled and a tooltip says "Not available for this wallpaper".

**Acceptance Criteria:**
- Toggle enables/disables depth effect
- Preview card updates when depth is toggled
- Disabled state shown correctly when wallpaper has no mask
- "PREVIEW" label appears on preview card

**Estimated Complexity:** Medium

---

### TASK-067 — Implement CustomizePage

**Feature:** Customize  
**Files:**
- `lib/features/customize/presentation/pages/customize_page.dart`

**Dependencies:** TASK-063, TASK-064, TASK-065, TASK-066, TASK-061, TASK-018  
**Description:**  
Full-bleed wallpaper background image. `Stack`:
1. `CachedNetworkImage` (wallpaper fill)
2. `ClockRendererWidget` (clock preview overlay)
3. `DraggableScrollableSheet` (bottom panel):
   - `BottomSheetHandle` at top
   - `SegmentedControl` (Clock | Styles | Depth) — sticky
   - Content area: `IndexedStack` or `AnimatedSwitcher` for tab content
   - Content tabs: `ClockSettingsPanel`, `ClockStylesPanel`, `DepthSettingsPanel`
4. Back button top-left (frosted circular)
5. "✓ Apply Wallpaper" button at very bottom (always visible, above panel or pinned in panel)

**Blocs provided:** `MultiBlocProvider` providing `CustomizeBloc`, `ClockBloc`, `DepthBloc`.

**Acceptance Criteria:**
- Full-bleed wallpaper visible behind panel
- Live clock preview updates in real time with any config change
- Tab switching is smooth (animated)
- Panel is draggable (expand/collapse between snap points)
- "Apply Wallpaper" always visible
- Back button works

**Estimated Complexity:** Very High

---

## Phase 12 — Depth Engine (Flutter)

---

### TASK-068 — Implement DepthConfig Domain Layer

**Feature:** Depth Engine  
**Files:**
- `lib/features/depth/domain/entities/depth_config_entity.dart`
- `lib/features/depth/domain/repositories/depth_repository.dart`
- `lib/features/depth/domain/usecases/save_depth_config_usecase.dart`
- `lib/features/depth/data/repositories/depth_repository_impl.dart`

**Dependencies:** TASK-007  
**Description:**  
`DepthConfigEntity`: `enabled: bool`, `wallpaperId: String`, `hasForegroundMask: bool`. Stored in Hive. `SaveDepthConfigUseCase` writes to Hive.

**Acceptance Criteria:**
- Config persists in Hive
- `hasForegroundMask` derived from `WallpaperEntity.hasForegroundMask`

**Estimated Complexity:** Low

---

### TASK-069 — Implement DepthBloc

**Feature:** Depth Engine  
**Files:**
- `lib/features/depth/presentation/bloc/depth_bloc.dart`

**Dependencies:** TASK-068  
**Description:**  
Handles `DepthEffectToggled`. If `wallpaperSupportsDepth = false` and toggle attempted, emits `DepthNotSupported` (with snackbar feedback in UI). Otherwise emits updated `DepthReady(config)`.

**Acceptance Criteria:**
- Toggling depth when supported updates config
- Toggling depth when unsupported emits `DepthNotSupported` with appropriate message

**Estimated Complexity:** Low

---

### TASK-070 — Implement DepthPreviewWidget

**Feature:** Depth Engine  
**Files:**
- `lib/features/depth/presentation/widgets/depth_preview_widget.dart`

**Dependencies:** TASK-061  
**Description:**  
Layered `Stack` for depth preview inside the Depth tab panel card: background wallpaper image → clock renderer → foreground mask image (if available). Rounded card container. "PREVIEW" label overlaid bottom-center (small, gray, letter-spaced).

**Acceptance Criteria:**
- Three-layer stack renders correctly
- When depth disabled or no mask: clock renders on top of wallpaper normally
- "PREVIEW" label visible
- Card has rounded corners matching design

**Estimated Complexity:** Medium

---

## Phase 13 — Native Android: Wallpaper Apply

---

### TASK-071 — Implement Flutter WallpaperChannel

**Feature:** Native — Apply  
**Files:**
- `lib/channels/wallpaper_channel.dart`

**Dependencies:** TASK-001  
**Description:**  
Flutter-side `MethodChannel` wrapper class. Methods:
- `applyWallpaper({required String imageUrl, required ApplyDestination destination, ClockConfig? clockConfig, bool depthEnabled, String? foregroundMaskUrl}) → Future<bool>`
- `requestWallpaperPermission() → Future<bool>`

Encodes all params as `Map<String, dynamic>` before calling channel.

**Acceptance Criteria:**
- Channel name matches Kotlin exactly: `com.creative.backgrounds/wallpaper`
- All param serialization is correct
- Returns `true` on success, throws on error

**Estimated Complexity:** Medium

---

### TASK-072 — Implement Kotlin WallpaperChannel Handler

**Feature:** Native — Apply  
**Files:**
- `android/app/src/main/kotlin/com/creative/backgrounds/channels/WallpaperChannel.kt`
- `android/app/src/main/kotlin/com/creative/backgrounds/MainActivity.kt`

**Dependencies:** TASK-071  
**Description:**  
Register `MethodChannel` in `MainActivity.configureFlutterEngine`. Handle `applyWallpaper` method: parse args, call `WallpaperApplyService.apply(...)` on IO dispatcher, reply with result. Handle `requestWallpaperPermission`: check and request `SET_WALLPAPER` permission, reply with granted/denied.

**Acceptance Criteria:**
- Channel registered and receives calls from Flutter
- Method runs on background thread (not main thread)
- Correct result returned to Flutter

**Estimated Complexity:** Medium

---

### TASK-073 — Implement WallpaperApplyService.kt

**Feature:** Native — Apply  
**Files:**
- `android/app/src/main/kotlin/com/creative/backgrounds/WallpaperApplyService.kt`

**Dependencies:** TASK-072  
**Description:**  
`apply(context, imageUrl, destination, clockConfigJson, depthEnabled, foregroundMaskUrl)`:
1. Download image with `OkHttp` (or use `BitmapFactory.decodeStream`)
2. If `depthEnabled && foregroundMaskUrl != null`: download foreground mask
3. Call `DepthCompositor.compositeWallpaper(background, foreground?, clockConfig)`
4. Set wallpaper with `WallpaperManager.getInstance(context).setBitmap(bitmap, null, true, flags)`
5. Return success/error

**Android WallpaperManager flags:**
- Home Screen: `WallpaperManager.FLAG_SYSTEM`
- Lock Screen: `WallpaperManager.FLAG_LOCK`  
- Both: `FLAG_SYSTEM or FLAG_LOCK`

**Acceptance Criteria:**
- Wallpaper applies to correct destination
- Download handles network errors gracefully
- Does not block main thread
- Memory: recycle bitmaps after use to avoid OOM

**Estimated Complexity:** High

---

## Phase 14 — Native Android: Live Wallpaper

---

### TASK-074 — Implement ClockRenderer.kt

**Feature:** Native — Live Wallpaper  
**Files:**
- `android/app/src/main/kotlin/com/creative/backgrounds/ClockRenderer.kt`

**Dependencies:** TASK-072  
**Description:**  
Reads `ClockConfig` from `SharedPreferences` (written by `ClockChannel`). Implements `render(canvas: Canvas, width: Int, height: Int, now: Calendar)`:
1. Load correct `Typeface` from assets based on `ClockConfig.font`
2. Create `Paint` with `textSize = config.sizePx`, `color = config.color`, `alpha = (config.opacity * 255).toInt()`
3. If `showShadow`: `paint.setShadowLayer(8f, 0f, 4f, Color.BLACK)`
4. If `showGlow`: use `BlurMaskFilter` on paint
5. Format time string (12h/24h, seconds)
6. Draw time centered at position (top=20% height, center=50%, bottom=80%)
7. If `showDate`: draw date string below time
8. If `showStroke`: draw text outline separately

**Acceptance Criteria:**
- Clock renders identically to Flutter preview on screen
- All config options respected
- Typefaces load from assets correctly

**Estimated Complexity:** High

---

### TASK-075 — Implement LiveWallpaperService.kt

**Feature:** Native — Live Wallpaper  
**Files:**
- `android/app/src/main/kotlin/com/creative/backgrounds/LiveWallpaperService.kt`

**Dependencies:** TASK-074  
**Description:**  
`WallpaperService` subclass with inner `Engine` class:
- `onCreate()`: load background bitmap from path stored in SharedPreferences
- `onDraw(canvas)`: draw background bitmap, call `ClockRenderer.render(canvas, width, height, Calendar.getInstance())`
- `onVisibilityChanged(visible)`: start/stop tick handler
- Tick handler: `Handler(Looper.getMainLooper()).postDelayed({ engine.invalidate() }, 1000L)`
- `onSurfaceChanged`: resize background bitmap if needed
- `onDestroy()`: remove handler callbacks, recycle bitmap

**Acceptance Criteria:**
- Background renders correctly as wallpaper
- Clock ticks every second
- Handler stops when wallpaper not visible (battery optimization)
- No memory leaks (bitmap recycled on destroy)

**Estimated Complexity:** High

---

### TASK-076 — Implement Flutter ClockChannel

**Feature:** Native — Clock Channel  
**Files:**
- `lib/channels/clock_channel.dart`
- `android/app/src/main/kotlin/com/creative/backgrounds/channels/ClockChannel.kt`

**Dependencies:** TASK-058  
**Description:**  
Flutter: `ClockChannel.saveClockConfig(ClockConfig) → Future<void>` — serializes config to JSON, calls `MethodChannel('com.creative.backgrounds/clock').invokeMethod('saveClockConfig', json)`.  
Kotlin: handles `saveClockConfig` method, writes JSON to `SharedPreferences` under key `clock_config_json`. Native renderers read from this key.

**Acceptance Criteria:**
- Config JSON written to SharedPreferences on every save
- Native rendering picks up new config on next draw

**Estimated Complexity:** Low

---

## Phase 15 — Native Android: Depth Compositor

---

### TASK-077 — Implement DepthCompositor.kt

**Feature:** Native — Depth  
**Files:**
- `android/app/src/main/kotlin/com/creative/backgrounds/DepthCompositor.kt`

**Dependencies:** TASK-074  
**Description:**  
`compositeWallpaper(background: Bitmap, foreground: Bitmap?, clockConfig: ClockConfig?, screenWidth: Int, screenHeight: Int): Bitmap`:
1. Create output `Bitmap(screenWidth, screenHeight, ARGB_8888)`
2. Create `Canvas(output)`
3. Scale and draw background bitmap to fill canvas
4. If `clockConfig != null`: call `ClockRenderer.render(canvas, ...)`
5. If `foreground != null`: scale and draw foreground bitmap on top
6. Return output bitmap

**Fallback:** If `foreground == null` and depth was requested: clock draws on top of background as normal wallpaper (no depth effect but no crash).

**Acceptance Criteria:**
- Three-layer composition produces correct bitmap
- Foreground PNG alpha channel preserved (transparent areas show clock behind)
- Fallback path works when no foreground
- Output bitmap dimensions match screen resolution

**Estimated Complexity:** High

---

## Phase 16 — Apply Flow + Success Screen

---

### TASK-078 — Implement ApplyWallpaperBloc

**Feature:** Apply Flow  
**Files:**
- `lib/features/apply_wallpaper/presentation/bloc/apply_wallpaper_bloc.dart`
- `lib/features/apply_wallpaper/domain/usecases/apply_wallpaper_usecase.dart`
- `lib/features/apply_wallpaper/data/repositories/apply_wallpaper_repository_impl.dart`

**Dependencies:** TASK-071  
**Description:**  
`ApplyWallpaperUseCase`: calls `WallpaperChannel.applyWallpaper(...)`. `ApplyWallpaperBloc`: on `ApplyWallpaperRequested`, emits `ApplyWallpaperInProgress` → calls use case → emits `ApplyWallpaperSuccess` or `ApplyWallpaperError(message)`.

**Acceptance Criteria:**
- Apply flow emits states in correct order
- Success navigates to `/success`
- Error shows snackbar/error overlay with retry

**Estimated Complexity:** Medium

---

### TASK-079 — Implement Apply Destination Bottom Sheet

**Feature:** Apply Flow  
**Files:**
- `lib/features/apply_wallpaper/presentation/pages/apply_wallpaper_page.dart`

**Dependencies:** TASK-078  
**Description:**  
Modal bottom sheet triggered from Wallpaper Details "Apply" button or Customize "Apply Wallpaper" button. Contains: title "Apply to...", three full-width pill buttons: "Home Screen", "Lock Screen", "Home + Lock Screen". Cancel text button. Tapping a destination closes sheet and dispatches `ApplyWallpaperRequested(destination, wallpaper, clockConfig, depthConfig)`.

**Acceptance Criteria:**
- Sheet opens correctly from both Details and Customize screens
- All three destinations work
- Loading overlay shows during apply
- Correct config passed to native

**Estimated Complexity:** Medium

---

### TASK-080 — Implement Success Screen

**Feature:** Apply Flow  
**Files:**
- `lib/features/apply_wallpaper/presentation/pages/success_page.dart`

**Dependencies:** TASK-011  
**Description:**  
Full-screen success screen. Center-aligned: animated checkmark (drawn-on path animation using `CustomPainter` + `AnimationController` drawing path progressively), "Wallpaper Applied!" headline, "Your wallpaper has been set successfully." subtext, "Done" button (navigates to `/explore` via `context.go`). Background: faded wallpaper thumbnail or plain white.

**Acceptance Criteria:**
- Checkmark animation plays on enter
- "Done" navigates to Explore (popping back to root)
- No back button (prevents re-apply)

**Estimated Complexity:** Medium

---

## Phase 17 — About / Privacy / Terms

*(covered in TASK-057 — implemented in Phase 9)*

---

## Phase 18 — Localization

---

### TASK-081 — Implement L10n String Tables

**Feature:** Localization  
**Files:**
- `lib/core/l10n/app_en.arb`
- `lib/core/l10n/app_ar.arb`
- `lib/core/l10n/l10n.dart` (generated)

**Dependencies:** TASK-001  
**Description:**  
Create `.arb` files for all user-visible strings. English strings extracted from all screens. Arabic translations provided. Configure `flutter_localizations` in `MaterialApp`. Use `AppLocalizations.of(context)!.discoverWallpapers` pattern throughout.

**Key string keys:** `discoverWallpapers`, `goodMorning`, `goodAfternoon`, `goodEvening`, `searchPlaceholder`, `trending`, `latest`, `viewAll`, `favorites`, `settings`, `language`, `autoChangeWallpaper`, `highQualityDownloads`, `clearCache`, `about`, `applyTo`, `homeScreen`, `lockScreen`, `homeAndLockScreen`, `customize`, `apply`, `applyWallpaper`, `wallpaperApplied`, `depthEffect`, `depthEffectDescription`, `clockPosition`, `clockFont`, `clockColor`, `clockSize`, `clockOpacity`, `shadow`, `glow`, `stroke`, `twentyFourHour`, `date`, `seconds`, `noFavorites`, `done`

**Acceptance Criteria:**
- All hardcoded strings replaced with localization keys
- Arabic strings display correctly in RTL mode
- Language switches take effect immediately

**Estimated Complexity:** Medium

---

### TASK-082 — Implement RTL Layout Support

**Feature:** Localization  
**Files:**
- All pages and widgets that have directional assumptions

**Dependencies:** TASK-081  
**Description:**  
Ensure all layouts use `start`/`end` not `left`/`right`. Check that carousel direction, grid order, and settings rows flip correctly in RTL. Test `FloatingBottomNav` in RTL. Ensure Arabic text in `LanguageToggle` renders without clipping.

**Acceptance Criteria:**
- App layout is fully mirrored in Arabic/RTL mode
- No text clipping or overflow in Arabic
- Navigation gestures (back swipe) still work

**Estimated Complexity:** Medium

---

## Phase 19 — Connectivity & Error States

---

### TASK-083 — Implement Offline Banner

**Feature:** Connectivity  
**Files:**
- `lib/app.dart`
- `lib/core/widgets/offline_banner.dart`

**Dependencies:** TASK-008  
**Description:**  
`OfflineBanner`: thin top banner ("No internet connection") that slides down when offline, slides up when back online. `AnimatedContainer` transition. Provided at root level via `BlocListener<ConnectivityBloc, ConnectivityState>`.

**Acceptance Criteria:**
- Banner appears within 1s of connectivity loss
- Banner disappears within 1s of connectivity restoration
- Does not cover critical UI elements when visible

**Estimated Complexity:** Low

---

### TASK-084 — Implement Retry Logic in All Blocs

**Feature:** Error Handling  
**Files:**
- All Bloc files

**Dependencies:** TASK-006  
**Description:**  
Ensure all Blocs that make network calls expose a retry event (e.g., `ExploreRefreshRequested`, `WallpaperDetailsFetchRequested` re-dispatch). Connect all `ErrorView` retry buttons to the correct Bloc retry event.

**Acceptance Criteria:**
- Every error state has a functioning retry
- Retry re-emits loading state before fetching
- After reconnecting to internet, refresh can be triggered

**Estimated Complexity:** Medium

---

## Phase 20 — Performance & Polish

---

### TASK-085 — Performance Audit: Image Loading

**Feature:** Performance  
**Files:**
- All pages using `CachedNetworkImage`

**Dependencies:** All screen tasks  
**Description:**  
Audit all `CachedNetworkImage` usages. Set `memCacheWidth` and `memCacheHeight` to display pixel size (use `MediaQuery` or fixed sizes). Set `maxHeightDiskCache` and `maxWidthDiskCache` to `2000` on `DefaultCacheManager`. Use `imageBuilder` with proper fit. Add `errorWidget` placeholder to all usages.

**Acceptance Criteria:**
- No OOM crash on device with 2GB RAM during grid scrolling
- Image cache does not exceed 200MB on disk
- Grid scrolls at 60 FPS on mid-range device

**Estimated Complexity:** Medium

---

### TASK-086 — Animation Polish

**Feature:** Animations  
**Files:**
- All animation-using widgets

**Dependencies:** All screen tasks  
**Description:**  
Implement and polish all animations from implementation_plan.md §16:
- Hero transition curves and duration
- FloatingBottomNav fade timing
- Favorite heart spring animation
- Clock style card selection micro-bounce
- Success checkmark draw-on animation
- Bottom sheet slide-up with correct snap points
- Search bar expansion

Ensure `MediaQuery.of(context).disableAnimations` is respected (accessibility reduced motion).

**Acceptance Criteria:**
- All animations play at correct timing
- No jank during animations (use `flutter_test`'s `pumpAndSettle` in widget tests)
- Reduced motion accessibility mode disables non-essential animations

**Estimated Complexity:** High

---

### TASK-087 — Accessibility Audit

**Feature:** Accessibility  
**Files:**
- All widget files

**Dependencies:** All screen tasks  
**Description:**  
Add `Semantics` labels to: all icon buttons, wallpaper cards (include wallpaper name and category), toggle switches (include current state), sliders (include label and current value). Ensure all touch targets are minimum 48×48dp. Test with TalkBack enabled on Android device.

**Acceptance Criteria:**
- TalkBack can navigate all interactive elements
- Screen reader announces correct labels
- No inaccessible interactive elements (missing labels)

**Estimated Complexity:** Medium

---

### TASK-088 — Final QA Checklist

**Feature:** QA  
**Files:** Documentation only

**Dependencies:** All tasks  
**Description:**  
QA engineer validates against this checklist:

**Functional:**
- [ ] Splash initializes and navigates to Explore
- [ ] Explore shows Trending, Latest, and category carousels
- [ ] Trending carousel shows PRO badge on premium wallpapers
- [ ] "View All" navigates with correct section title
- [ ] View All filter/sort works and reloads grid
- [ ] Search returns results with debounce
- [ ] Search history shown on empty query
- [ ] Wallpaper Details shows full image, name, resolution, category
- [ ] Favorite toggle works from Details and Favorites screen
- [ ] Share opens system share sheet
- [ ] Customize → Clock tab: all controls update preview in real time
- [ ] Position (Top/Center/Bottom) moves clock correctly
- [ ] Font (Inter/Serif/Mono) changes clock font correctly
- [ ] Color swatches change clock color
- [ ] Size slider moves from 24–120px
- [ ] Opacity slider at 0% makes clock invisible
- [ ] Shadow toggle adds/removes shadow
- [ ] Glow toggle adds/removes glow effect
- [ ] Stroke toggle adds/removes stroke
- [ ] 24-Hour toggle switches format
- [ ] Date toggle shows/hides date
- [ ] Seconds toggle shows/hides seconds
- [ ] Styles tab shows all clock styles, selection updates preview
- [ ] Depth tab toggle enables/disables depth
- [ ] Depth unavailable message shown for wallpapers without mask
- [ ] Apply Wallpaper opens destination sheet
- [ ] All three apply destinations work on physical device
- [ ] Success screen appears after apply
- [ ] Favorites screen shows all saved wallpapers
- [ ] Empty state shown when no favorites
- [ ] Settings: Language toggle switches language
- [ ] Settings: Arabic switches to RTL layout
- [ ] Settings: Auto-change toggle persists
- [ ] Settings: HQ downloads toggle persists
- [ ] Settings: Clear cache clears and updates size
- [ ] Settings: About navigates to about page

**Performance:**
- [ ] App cold start < 2s on mid-range device
- [ ] Grid scrolling at 60 FPS
- [ ] No OOM during extended use

**Offline:**
- [ ] Cached content shows when offline
- [ ] Offline banner appears when no internet
- [ ] Retry works when internet restored

**Estimated Complexity:** Medium

---

## Dependency Map Summary

```
Phase 0 (Bootstrap) ──────────────────────────────────────────────────────────┐
  └─► Phase 1 (Core Infrastructure) ──────────────────────────────────────────┤
        └─► Phase 2 (Design System) ──────────────────────────────────────────┤
              ├─► Phase 3 (Splash) ─────────────────────────────────────────► │
              ├─► Phase 4 (Explore) ───────────────────────────────────────► │
              ├─► Phase 5 (Search) ────────────────────────────────────────► │
              ├─► Phase 6 (View All) ──────────────────────────────────────► │
              ├─► Phase 7 (Wallpaper Details) ──────────────────────────────► │
              ├─► Phase 8 (Favorites) ─────────────────────────────────────► │
              ├─► Phase 9 (Settings) ──────────────────────────────────────► │
              ├─► Phase 10 (Clock Engine Flutter) ──────────────────────────► │
              │     └─► Phase 11 (Customize Screen) ──────────────────────► │
              │           └─► Phase 12 (Depth Engine Flutter) ────────────► │
              └─► Phase 13 (Native: Apply) ─────────────────────────────────► │
                    └─► Phase 14 (Native: Live Wallpaper) ─────────────────► │
                          └─► Phase 15 (Native: Depth Compositor) ─────────► │
                                └─► Phase 16 (Apply Flow + Success) ────────► │
                                      └─► Phases 17–20 (Polish + QA) ──────► ┘
```

---

## Task Count Summary

| Phase | Tasks | Complexity |
|-------|-------|-----------|
| 0 — Bootstrap | 4 | Low |
| 1 — Core Infrastructure | 6 | Low–Medium |
| 2 — Design System | 14 | Low–Medium |
| 3 — Splash | 2 | Low–Medium |
| 4 — Explore | 11 | Medium–High |
| 5 — Search | 3 | Medium |
| 6 — View All | 5 | Medium |
| 7 — Wallpaper Details | 4 | Medium–High |
| 8 — Favorites | 3 | Medium |
| 9 — Settings | 5 | Low–Medium |
| 10 — Clock Engine (Flutter) | 5 | Medium–High |
| 11 — Customize Screen | 5 | High–Very High |
| 12 — Depth Engine (Flutter) | 3 | Low–Medium |
| 13 — Native: Apply | 3 | Medium–High |
| 14 — Native: Live Wallpaper | 3 | High |
| 15 — Native: Depth Compositor | 1 | High |
| 16 — Apply Flow + Success | 3 | Medium |
| 17 — Static Pages | (see TASK-057) | Low |
| 18 — Localization | 2 | Medium |
| 19 — Connectivity & Errors | 2 | Low–Medium |
| 20 — Performance & Polish | 4 | Medium–High |
| **Total** | **88 tasks** | |

---

*End of Tasks Document*  
*Every task is atomic, implementation-ready, and cross-referenced to implementation_plan.md.*
