# Creative Backgrounds — Implementation Plan
**Version:** 1.0  
**Platform:** Android (Flutter + Native Kotlin)  
**Architecture:** Clean Architecture · Feature-first · Repository Pattern  
**Date:** 2026-07-13  
**Status:** Pre-Implementation Reference Document

---

## Table of Contents

1. [UI/UX Audit](#1-uiux-audit)
2. [Design System](#2-design-system)
3. [Folder Structure](#3-folder-structure)
4. [Feature Architecture](#4-feature-architecture)
5. [Screen Specifications](#5-screen-specifications)
6. [State Management — All Blocs](#6-state-management--all-blocs)
7. [Navigation Architecture](#7-navigation-architecture)
8. [Clock Engine](#8-clock-engine)
9. [Depth Engine](#9-depth-engine)
10. [Native Android Modules](#10-native-android-modules)
11. [Backend Contract](#11-backend-contract)
12. [Local Storage](#12-local-storage)
13. [Dependency Injection](#13-dependency-injection)
14. [Environment Variables](#14-environment-variables)
15. [Android Permissions](#15-android-permissions)
16. [Animations](#16-animations)
17. [Non-Functional Requirements](#17-non-functional-requirements)
18. [Error Handling Strategy](#18-error-handling-strategy)

---

## 1. UI/UX Audit

### 1.1 Screen Inventory

| # | Screen | Route | Notes |
|---|--------|-------|-------|
| 1 | Splash | `/` | Animated logo, remote config load |
| 2 | Explore (Home) | `/explore` | Greeting header, search bar, Trending + Latest + Nature carousels |
| 3 | Explore Scrolled | `/explore` | Reveals floating bottom navigation pill |
| 4 | Wallpaper Details | `/wallpaper/:id` | Full-bleed image, dark overlay panel, Customize + Apply CTAs |
| 5 | Customize / Clock Tab | `/customize/:id` | Live preview, 3-tab segmented control, Clock settings panel |
| 6 | Customize / Clock Scrolled (Size+Opacity+Shadow+Glow) | `/customize/:id` | Sliders, toggles |
| 7 | Customize / Clock Scrolled (Glow+Stroke+24H+Date+Seconds) | `/customize/:id` | Additional toggles |
| 8 | Customize / Styles Tab | `/customize/:id` | 2×n grid of clock style cards (Modern, Minimal, Elegant, Digital …) |
| 9 | Customize / Depth Tab | `/customize/:id` | Depth Effect toggle + inline PREVIEW card |
| 10 | View All — Trending | `/view-all/trending` | Back + Search header, section title, Filters + Sort chips, 2-col staggered grid |
| 11 | View All — All | `/view-all/all` | Same layout, different data |
| 12 | Favorites | `/favorites` | Large title, 2-col staggered masonry grid, bottom nav active on heart |
| 13 | Settings | `/settings` | Large title, Language toggle (English / العربية), auto-change toggle, HQ downloads toggle, Clear cache row, About row, version footer, bottom nav active on sun |

### 1.2 Component Inventory

#### Global / Shared Components

| Component | Screens Used | Notes |
|-----------|-------------|-------|
| `AppSearchBar` | Explore, View All | Rounded pill, left search icon, placeholder "Search wallpapers…", white background |
| `FloatingBottomNav` | Explore, Favorites, Settings | Pill-shaped container with three icons: compass (Explore), heart (Favorites), sun (Settings). Active icon has filled black circle background |
| `SectionHeader` | Explore | Label (bold, ~18px), "View All ›" link right-aligned |
| `WallpaperCard` (small) | Explore carousels | Rounded corners (~16px), image fill, bottom-left text overlay (title bold white, subtitle smaller gray) |
| `WallpaperCard` (PRO badge) | Explore Trending | Small "PRO" pill in top-right corner |
| `WallpaperCard` (grid) | View All, Favorites | Two-column, staggered height, rounded corners, name + category overlaid bottom-left |
| `ClockPreview` | Customize, Depth tab | Live rendering of current clock config overlaid on wallpaper |
| `SegmentedControl` | Customize | 3 segments: Clock · Styles · Depth; pill-within-pill UI, white selected pill |
| `OptionChipRow` | Customize / Clock (Position, Font) | Horizontal row of pill chips; selected = white fill |
| `ColorSwatch` | Customize / Clock (Color) | 4 round swatches: white, black, gray-blue, warm cream |
| `Slider` | Customize / Clock (Size, Opacity) | System-style slider with label + current value right-aligned |
| `ToggleRow` | Customize / Clock | Label left, Switch right; used for Shadow, Glow, Stroke, 24-Hour, Date, Seconds |
| `ClockStyleCard` | Customize / Styles | Frosted card ~50% width, clock preview with label underneath; selected state = white border |
| `DepthPreviewCard` | Customize / Depth | Inline mini preview card showing wallpaper + clock + "PREVIEW" label |
| `FilterChip` | View All | "⊞ Filters" pill |
| `SortChip` | View All | "↕ Sort" pill |
| `SettingsRow` | Settings | Label + subtitle + right widget (toggle, chevron, or language pills) |
| `LanguageToggle` | Settings | Two rounded pill buttons side by side: English (selected, black fill), العربية |
| `BottomSheetHandle` | Customize panel | Short horizontal pill drag handle |
| `BackButton` | Wallpaper Details, Customize, View All | Circular frosted button, left-aligned |
| `ActionButton` (icon) | Wallpaper Details | Circular frosted button for heart + share |
| `GradientOverlay` | Wallpaper Details | Bottom dark gradient for info panel legibility |

#### Navigation

| Element | Description |
|---------|-------------|
| Bottom Nav | Three-tab pill; Explore (compass), Favorites (heart), Settings (sun icon) |
| Active state | Active icon has filled circular black background |
| Transition | Floating pill appears as content scrolls; hidden at top of Explore |

### 1.3 Typography Observations (from screens)

| Role | Appearance | Mapping |
|------|-----------|---------|
| Page title | "Discover Wallpapers" — very large, bold, black | Display/H1 |
| Eyebrow | "GOOD MORNING" — small caps, gray | Overline |
| Section header | "Trending", "Latest", "Nature" — semibold, ~18px | H3 |
| Card title | "Tokyo Dusk", "Aurora" — white, bold, ~14px | BodyLarge Bold |
| Card subtitle | "Neon", "Space" — white, medium, ~11px | Caption |
| Details title | "Aurora" — white bold ~22px, "Space · 2160 × 3840" smaller | BodyLarge |
| Clock display | "5:37" / "5:38" — very large white, font varies by style | ClockDisplay |
| Clock date | "Monday, July 13" — medium weight white | ClockDate |
| Panel label | "POSITION", "FONT", "COLOR", "Size", "Opacity" | Label/Overline |
| Settings row label | "Language", "Auto-change wallpaper" — bold ~16px | BodyLarge |
| Settings row subtitle | "App display language", "A new wallpaper every day" — gray ~13px | BodySmall |
| Version footer | "Creative Backgrounds · 1.0.0" — centered gray | Caption |

### 1.4 Color Palette (observed from screens)

| Token | Value | Usage |
|-------|-------|-------|
| `colorBackground` | `#F2F2F7` (iOS-gray-like off-white) | App background (light mode) |
| `colorSurface` | `#FFFFFF` | Search bar, chips, panel |
| `colorPanel` | `rgba(30,35,50,0.75)` frosted | Bottom panel on customize |
| `colorTextPrimary` | `#0D0D0D` | Page titles, bold labels |
| `colorTextSecondary` | `#8E8E93` | Subtitles, helper text |
| `colorTextOnImage` | `#FFFFFF` | Card overlays, clock |
| `colorProBadge` | `#FFFFFF` | "PRO" chip fill |
| `colorActiveNav` | `#0D0D0D` | Active bottom nav background |
| `colorChipSelected` | `#FFFFFF` | Selected segment/chip |
| `colorChipUnselected` | `transparent` | Unselected segment/chip |
| `colorSettings` | `#FFFFFF` | Settings row background |
| `colorDivider` | `#E5E5EA` | Settings row dividers |

### 1.5 Spacing & Shape

| Token | Value |
|-------|-------|
| `radiusCard` | 16 dp |
| `radiusLarge` | 24 dp |
| `radiusPill` | 999 dp |
| `paddingScreen` | 20 dp horizontal |
| `paddingSection` | 16 dp vertical between sections |
| `gridSpacing` | 8 dp |
| `carouselHeight` | ~300 dp (Large card), ~220 dp (smaller peek cards visible) |
| `bottomNavHeight` | 56 dp (pill) |
| `panelRadius` | 24 dp top corners |

### 1.6 User Flow (confirmed from screens)

```
Splash
  └─► Explore
        ├─► [tap search bar] Search
        ├─► [tap "View All"] View All (Trending / Latest / Category)
        │     └─► [tap card] Wallpaper Details
        └─► [tap card] Wallpaper Details
                  ├─► [tap ♡] Toggle Favorite (inline)
                  ├─► [tap Share] Share Sheet (system)
                  ├─► [tap "Customize"] Clock Editor
                  │     ├─► Clock Tab (Position, Font, Color, Size, Opacity, Shadow, Glow, Stroke, 24H, Date, Seconds)
                  │     ├─► Styles Tab (clock style grid)
                  │     ├─► Depth Tab (depth effect toggle + preview)
                  │     └─► [tap "Apply Wallpaper"] Apply Flow → Success
                  └─► [tap "Apply"] Apply Flow → Success

Bottom Nav:
  ├─► [compass] → Explore
  ├─► [heart] → Favorites
  └─► [sun] → Settings
        └─► About / Privacy / Terms
```

---

## 2. Design System

### 2.1 Theme Tokens

```dart
// lib/core/theme/app_colors.dart
// lib/core/theme/app_text_styles.dart
// lib/core/theme/app_spacing.dart
// lib/core/theme/app_shapes.dart
// lib/core/theme/app_theme.dart
```

**Color tokens (light mode — only mode visible in designs):**

```
colorBackground     : #F2F2F7
colorSurface        : #FFFFFF
colorPrimaryText    : #0D0D0D
colorSecondaryText  : #8E8E93
colorDivider        : #E5E5EA
colorPanel          : #1E2332 (at ~75% opacity with blur)
colorActiveNav      : #0D0D0D
colorProBadge       : #FFFFFF / #000000 text
colorSliderActive   : #0D0D0D
colorToggleActive   : #0D0D0D
colorChipSelected   : #FFFFFF
```

**Text styles:**

| Style Name | Font | Weight | Size | Usage |
|-----------|------|--------|------|-------|
| `displayLarge` | Inter | 700 | 32sp | Page titles ("Discover Wallpapers") |
| `overline` | Inter | 500 | 12sp | Eyebrow ("GOOD MORNING") |
| `h3` | Inter | 600 | 18sp | Section labels ("Trending") |
| `bodyLarge` | Inter | 600 | 16sp | Settings row label |
| `bodyMedium` | Inter | 400 | 14sp | Card titles |
| `bodySmall` | Inter | 400 | 13sp | Settings subtitles |
| `caption` | Inter | 400 | 11sp | Card category, version footer |
| `clockHuge` | (per style) | 700 | 76sp (configurable) | Clock time display |
| `clockDate` | (per style) | 500 | 16sp | Clock date line |

**Font families used in clock styles:**

| Style | Family | Weight |
|-------|--------|--------|
| Modern | Inter | 700 |
| Minimal | Inter | 300 |
| Elegant | Playfair Display / Cormorant | 400 italic |
| Digital | Courier Prime / JetBrains Mono | 700 |

### 2.2 Icon Set

Icons are outlined/system style. Confirmed icons:
- Compass (Explore nav)
- Heart (Favorites nav + Details action)
- Sun/brightness (Settings nav)
- Search (magnifier)
- Share (upload arrow)
- Back chevron
- Checkmark (Apply Wallpaper CTA)
- Filter lines (Filters chip)
- Sort arrows (Sort chip)
- Settings gear (customize)
- Chevron-right (settings rows)

Use `lucide_flutter` or `material_symbols_flutter` with outlined variants.

---

## 3. Folder Structure

```
creative_backgrounds/
├── android/
│   ├── app/src/main/kotlin/com/creative/backgrounds/
│   │   ├── MainActivity.kt
│   │   ├── WallpaperApplyService.kt
│   │   ├── LiveWallpaperService.kt
│   │   ├── ClockRenderer.kt
│   │   ├── ClockPainter.kt
│   │   ├── DepthCompositor.kt
│   │   └── channels/
│   │       ├── WallpaperChannel.kt
│   │       └── ClockChannel.kt
├── lib/
│   ├── main.dart
│   ├── app.dart                          # App widget, GoRouter init, GetIt init
│   ├── injection.dart                    # GetIt registration
│   │
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart           # Env vars, constants
│   │   │   └── remote_config.dart
│   │   ├── network/
│   │   │   ├── dio_client.dart
│   │   │   ├── api_interceptor.dart
│   │   │   └── network_info.dart
│   │   ├── error/
│   │   │   ├── failures.dart
│   │   │   ├── exceptions.dart
│   │   │   └── error_handler.dart
│   │   ├── storage/
│   │   │   ├── hive_storage.dart
│   │   │   └── storage_keys.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   ├── app_spacing.dart
│   │   │   ├── app_shapes.dart
│   │   │   └── app_theme.dart
│   │   ├── router/
│   │   │   ├── app_router.dart
│   │   │   └── route_names.dart
│   │   ├── utils/
│   │   │   ├── extensions.dart
│   │   │   └── validators.dart
│   │   └── widgets/
│   │       ├── app_search_bar.dart
│   │       ├── floating_bottom_nav.dart
│   │       ├── wallpaper_card.dart
│   │       ├── section_header.dart
│   │       ├── pro_badge.dart
│   │       ├── back_button.dart
│   │       ├── filter_chip.dart
│   │       ├── sort_chip.dart
│   │       ├── segmented_control.dart
│   │       ├── option_chip_row.dart
│   │       ├── color_swatch_row.dart
│   │       ├── labeled_slider.dart
│   │       ├── toggle_row.dart
│   │       ├── settings_row.dart
│   │       ├── bottom_sheet_handle.dart
│   │       ├── error_view.dart
│   │       ├── loading_shimmer.dart
│   │       └── empty_state_view.dart
│   │
│   ├── features/
│   │   ├── splash/
│   │   │   ├── presentation/
│   │   │   │   ├── bloc/splash_bloc.dart
│   │   │   │   └── pages/splash_page.dart
│   │   │   └── domain/
│   │   │       └── usecases/initialize_app_usecase.dart
│   │   │
│   │   ├── explore/
│   │   │   ├── data/
│   │   │   │   ├── models/wallpaper_model.dart
│   │   │   │   ├── models/category_model.dart
│   │   │   │   ├── datasources/explore_remote_datasource.dart
│   │   │   │   └── repositories/explore_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/wallpaper_entity.dart
│   │   │   │   ├── entities/category_entity.dart
│   │   │   │   ├── repositories/explore_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── get_trending_wallpapers_usecase.dart
│   │   │   │       ├── get_latest_wallpapers_usecase.dart
│   │   │   │       └── get_categories_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/explore_bloc.dart
│   │   │       ├── pages/explore_page.dart
│   │   │       └── widgets/
│   │   │           ├── greeting_header.dart
│   │   │           ├── trending_carousel.dart
│   │   │           ├── latest_carousel.dart
│   │   │           └── category_carousel.dart
│   │   │
│   │   ├── search/
│   │   │   ├── data/
│   │   │   │   ├── datasources/search_remote_datasource.dart
│   │   │   │   └── repositories/search_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── repositories/search_repository.dart
│   │   │   │   └── usecases/search_wallpapers_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/search_bloc.dart
│   │   │       └── pages/search_page.dart
│   │   │
│   │   ├── view_all/
│   │   │   ├── data/
│   │   │   │   ├── datasources/view_all_remote_datasource.dart
│   │   │   │   └── repositories/view_all_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── repositories/view_all_repository.dart
│   │   │   │   └── usecases/get_section_wallpapers_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/view_all_bloc.dart
│   │   │       ├── pages/view_all_page.dart
│   │   │       └── widgets/
│   │   │           ├── wallpaper_grid.dart
│   │   │           ├── filter_bottom_sheet.dart
│   │   │           └── sort_bottom_sheet.dart
│   │   │
│   │   ├── wallpaper_details/
│   │   │   ├── data/
│   │   │   │   ├── datasources/wallpaper_details_remote_datasource.dart
│   │   │   │   └── repositories/wallpaper_details_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── repositories/wallpaper_details_repository.dart
│   │   │   │   └── usecases/get_wallpaper_details_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/wallpaper_details_bloc.dart
│   │   │       ├── pages/wallpaper_details_page.dart
│   │   │       └── widgets/
│   │   │           ├── wallpaper_info_panel.dart
│   │   │           └── wallpaper_action_buttons.dart
│   │   │
│   │   ├── customize/
│   │   │   ├── presentation/
│   │   │   │   ├── bloc/customize_bloc.dart
│   │   │   │   ├── pages/customize_page.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── customize_tab_bar.dart
│   │   │   │       ├── clock_settings_panel.dart
│   │   │   │       ├── clock_styles_panel.dart
│   │   │   │       └── depth_settings_panel.dart
│   │   │   └── domain/
│   │   │       └── usecases/save_customization_usecase.dart
│   │   │
│   │   ├── clock/
│   │   │   ├── data/
│   │   │   │   ├── models/clock_config_model.dart
│   │   │   │   └── repositories/clock_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/clock_config_entity.dart
│   │   │   │   ├── repositories/clock_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── save_clock_config_usecase.dart
│   │   │   │       └── load_clock_config_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/clock_bloc.dart
│   │   │       └── widgets/
│   │   │           ├── clock_renderer_widget.dart
│   │   │           └── clock_painter.dart
│   │   │
│   │   ├── depth/
│   │   │   ├── data/
│   │   │   │   ├── models/depth_config_model.dart
│   │   │   │   └── repositories/depth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/depth_config_entity.dart
│   │   │   │   ├── repositories/depth_repository.dart
│   │   │   │   └── usecases/save_depth_config_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/depth_bloc.dart
│   │   │       └── widgets/
│   │   │           └── depth_preview_widget.dart
│   │   │
│   │   ├── apply_wallpaper/
│   │   │   ├── data/
│   │   │   │   └── repositories/apply_wallpaper_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── repositories/apply_wallpaper_repository.dart
│   │   │   │   └── usecases/apply_wallpaper_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/apply_wallpaper_bloc.dart
│   │   │       ├── pages/apply_wallpaper_page.dart
│   │   │       └── pages/success_page.dart
│   │   │
│   │   ├── favorites/
│   │   │   ├── data/
│   │   │   │   ├── datasources/favorites_local_datasource.dart
│   │   │   │   ├── datasources/favorites_remote_datasource.dart
│   │   │   │   └── repositories/favorites_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── repositories/favorites_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── get_favorites_usecase.dart
│   │   │   │       ├── add_favorite_usecase.dart
│   │   │   │       └── remove_favorite_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/favorites_bloc.dart
│   │   │       └── pages/favorites_page.dart
│   │   │
│   │   └── settings/
│   │       ├── data/
│   │       │   ├── datasources/settings_local_datasource.dart
│   │       │   └── repositories/settings_repository_impl.dart
│   │       ├── domain/
│   │       │   ├── repositories/settings_repository.dart
│   │       │   └── usecases/
│   │       │       ├── get_settings_usecase.dart
│   │       │       └── update_settings_usecase.dart
│   │       └── presentation/
│   │           ├── bloc/settings_bloc.dart
│   │           └── pages/
│   │               ├── settings_page.dart
│   │               ├── about_page.dart
│   │               ├── privacy_policy_page.dart
│   │               └── terms_page.dart
│   │
│   └── channels/
│       ├── wallpaper_channel.dart        # Flutter side of platform channel
│       └── clock_channel.dart
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── .env
└── pubspec.yaml
```

---

## 4. Feature Architecture

### 4.1 Clean Architecture Layers

Each feature follows the same three-layer pattern:

```
Presentation ──► Domain ◄── Data
     │              │          │
  BLoC          Entities    Models
  Pages        Use Cases    Remote DS
  Widgets    Repositories   Local DS
              (interface)   Repo Impl
```

**Rules:**
- Domain layer has zero Flutter/external dependencies
- Data layer implements domain repository interfaces
- Presentation depends only on domain (via use cases injected through BLoC)
- Use cases are injected via GetIt into BLoCs
- Models extend or implement entities; Freezed is used for immutability

### 4.2 Dependency Flow

```
GetIt registers:
  DioClient → ApiInterceptor → HiveStorage
  RemoteDataSource(Dio) → LocalDataSource(Hive) → RepositoryImpl
  UseCase(Repository) → Bloc(UseCase)
  Page injects Bloc via BlocProvider
```

---

## 5. Screen Specifications

### 5.1 Splash Screen

**Route:** `/`  
**Purpose:** App initialization, remote config fetch, navigation to Explore.

**Visual:**
- Full-screen white/dark background
- App logo centered with animated fade + scale in
- Subtle progress indicator (not intrusive)

**Logic:**
1. Initialize Hive boxes
2. Load local settings (theme, language)
3. Check network connectivity
4. Fetch remote config from API
5. Navigate to `/explore` after initialization completes (minimum 1.5s for branding)

**BLoC:** `SplashBloc`  
**Events:** `SplashInitialized`  
**States:** `SplashLoading`, `SplashReady`, `SplashError`

---

### 5.2 Explore Screen

**Route:** `/explore`  
**Purpose:** Primary discovery surface — trending, latest, and category-based wallpaper carousels.

**Layout (top to bottom):**
1. Status bar area — transparent
2. **Greeting header block** (top padding ~16dp):
   - Overline: "GOOD MORNING" (dynamic by time of day: GOOD MORNING / GOOD AFTERNOON / GOOD EVENING)
   - Title: "Discover Wallpapers" (Display/H1, 2 lines)
3. **Search bar** — full-width pill, rounded, light gray background, icon + placeholder
4. **"Trending" section:**
   - `SectionHeader` with "Trending" label and "View All ›" link
   - Horizontal `ListView` (carousel), peek effect (partial cards visible at edges)
   - Each card: large portrait rounded card (~280×350 dp), image fill, gradient overlay, title bottom-left, subtitle below title
   - Center card is elevated/scaled (centered carousel behavior)
   - PRO badge appears on premium wallpapers — white pill top-right of card
5. **"Latest" section:**
   - `SectionHeader` with "Latest" label and "View All ›"
   - Same carousel layout, slightly different card proportions
   - Cards show Aurora, Void, etc.
6. **Category sections** (e.g., "Nature"):
   - `SectionHeader` with category name and "View All ›"
   - Horizontal carousel
7. **Floating bottom navigation** (`FloatingBottomNav`):
   - Appears after initial scroll, fades in
   - Pill-shaped, white background, shadow
   - 3 icons: compass (active = filled black circle), heart, sun
   - Positioned ~16dp from bottom edge

**Infinite content:** Multiple category sections can be fetched dynamically from API.

**Scroll behavior:** 
- Greeting header collapses on scroll (optional animation)
- Search bar may collapse into top app bar or remain sticky
- Bottom nav floats over content always once visible

**BLoC:** `ExploreBloc`  
**Events:** `ExploreFetchTrending`, `ExploreFetchLatest`, `ExploreFetchCategories`, `ExploreRefresh`  
**States:** `ExploreInitial`, `ExploreLoading`, `ExploreLoaded(trending, latest, categories)`, `ExploreError`

---

### 5.3 Search Screen

**Route:** `/search` (or in-page overlay on Explore)  
**Purpose:** Search wallpapers by keyword, tag, or category.

**Layout:**
- Top bar with search field active (keyboard up), back arrow
- Search results in 2-column grid (same as View All)
- Empty state with search icon + instructional copy
- No-results state with suggestion to try different keywords
- Debounced search (300ms after last keystroke)

**BLoC:** `SearchBloc`  
**Events:** `SearchQueryChanged(query)`, `SearchCleared`, `SearchLoadMore`  
**States:** `SearchInitial`, `SearchLoading`, `SearchLoaded(results, query)`, `SearchEmpty`, `SearchError`

**Features:**
- Search history stored locally in Hive (last 10 queries)
- Recent searches shown as chips before query is entered
- Clear history button

---

### 5.4 View All Screen

**Route:** `/view-all/:section` (section = `trending` | `latest` | `all` | `:categoryId`)  
**Purpose:** Browse all wallpapers in a given section or category with filtering and sorting.

**Layout:**
1. **Top bar:**
   - Back button (circular frosted) — left
   - Search bar (pill) — center/right stretch
2. **Section title:** Bold large text (e.g., "Trending", "All") — left aligned, top padding
3. **Filter + Sort chips row:**
   - "⊞ Filters" pill chip — opens filter bottom sheet
   - "↕ Sort" pill chip — opens sort bottom sheet
   - Right-aligned
4. **Wallpaper grid:**
   - 2-column `GridView` with 8dp gap
   - Cards: full-width per column, equal-height square-ish, image fill, bottom-left text overlay (name bold, category colored by type)
   - Category color: Neon = orange/amber, Nature = green, Dark = blue, Mountains = blue-gray
5. **Infinite scroll:** `InfiniteScrollPagination` or custom with `ScrollController`
6. **Loading indicator** at bottom during pagination

**Filter Bottom Sheet:**
- Categories checkboxes
- Orientation (Portrait / Landscape / Both)
- Resolution filter
- Apply / Reset buttons

**Sort Bottom Sheet:**
- Trending, Latest, Most Downloaded, Alphabetical
- Radio list

**BLoC:** `ViewAllBloc` (reused across sections via route param)  
**Events:** `ViewAllFetch(section, page)`, `ViewAllFilterChanged(filter)`, `ViewAllSortChanged(sort)`, `ViewAllLoadMore`  
**States:** `ViewAllLoading`, `ViewAllLoaded(items, hasMore)`, `ViewAllError`

---

### 5.5 Wallpaper Details Screen

**Route:** `/wallpaper/:id`  
**Purpose:** Full preview + actions (favorite, share, customize, apply).

**Layout:**
- **Background:** Full-bleed image, edge-to-edge, extends behind status bar and navigation bar (no SafeArea clipping on image)
- **Top actions bar** (overlay on image, top-safe-area padding):
  - Back button — circular frosted glass, left
  - Favorite button — circular frosted glass, right (heart icon, filled when favorited)
  - Share button — circular frosted glass, right of favorite (upload/share icon)
- **Bottom info panel** (dark semi-transparent rounded container ~28dp top radius):
  - Wallpaper name (bold, white, ~22sp)
  - Category · Resolution (e.g., "Space · 2160 × 3840") — gray secondary text
  - Two buttons side by side:
    - "✦ Customize" — white outlined pill (white bg, black text, sun/sparkle icon)
    - "Apply" — dark filled pill (black bg, white text)
    - Buttons are equal-ish width, slight gap between

**Interactions:**
- Hero animation on card → details image
- Pinch-to-zoom on full image
- Tap outside panel → dismiss panel (panel is always visible per design)
- Heart icon toggles with animation (spring scale + fill color)

**BLoC:** `WallpaperDetailsBloc`  
**Events:** `WallpaperDetailsFetch(id)`, `WallpaperFavoriteToggled(id)`, `WallpaperShared(id)`  
**States:** `WallpaperDetailsLoading`, `WallpaperDetailsLoaded(wallpaper, isFavorite)`, `WallpaperDetailsError`

---

### 5.6 Customize Screen — Clock Tab

**Route:** `/customize/:wallpaperId`  
**Purpose:** Overlay clock on wallpaper and configure all clock properties.

**Layout:**
- **Background:** Full wallpaper image behind everything
- **Live clock preview** centered in upper portion (actual rendered clock on wallpaper)
- **Bottom panel** (draggable sheet, dark frosted glass, top corners rounded 24dp):
  - **Handle:** centered horizontal pill drag indicator
  - **Tab bar:** 3 segments — "Clock" | "Styles" | "Depth"

**Clock Tab — Page 1 (Position + Font + Color):**
- Label: "POSITION" (overline style)
- Chip row: "Top" | "Center" | "Bottom" — selected = white fill
- Label: "FONT"
- Chip row: "Inter" | "Serif" | "Mono" — selected = white fill
- Label: "COLOR"
- Swatch row: 4 circles — white, black, gray-blue, warm cream/beige
- Label row: "Size" + value "76px" right-aligned

**Clock Tab — Page 2 (Size + Opacity + Shadow + Glow, scrolled):**
- Slider: Size (current: 76px, labeled right)
- Slider: Opacity (current: 100%, labeled right)
- Toggle row: Shadow (ON per design)
- Toggle row: Glow (OFF per design)

**Clock Tab — Page 3 (Glow + Stroke + 24H + Date + Seconds, further scrolled):**
- Toggle row: Glow
- Toggle row: Stroke
- Toggle row: 24-Hour
- Toggle row: Date (ON per design)
- Toggle row: Seconds (OFF per design)

**The bottom panel is a single scrollable column** — all the above sections scroll vertically within the panel. The segmented tab bar is sticky at the top of the panel.

**Apply button:** Always visible at bottom — "✓ Apply Wallpaper" pill (white, full width)

**BLoC:** `ClockBloc` (for all clock state), `CustomizeBloc` (for tab management, apply orchestration)

---

### 5.7 Customize Screen — Styles Tab

**Route:** `/customize/:wallpaperId` (tab: styles)  
**Purpose:** Select a clock visual style from a grid.

**Layout:**
- Same full-bleed wallpaper + live clock preview (preview updates instantly on style selection)
- Same bottom panel with tab bar
- **Styles grid:** 2-column grid of `ClockStyleCard` widgets:
  - Each card: frosted dark background, shows "09:41" in the target style, label below (e.g., "Modern", "Minimal", "Elegant", "Digital")
  - **Selected state:** White border/outline around card
  - Visible styles (from design): Modern, Minimal, Elegant, Digital + more (grid scrolls)

**Interaction:**
- Tapping a style card immediately updates the live clock preview in the upper portion
- Selected card animates border highlight

**Apply button:** Always visible — "✓ Apply Wallpaper"

---

### 5.8 Customize Screen — Depth Tab

**Route:** `/customize/:wallpaperId` (tab: depth)  
**Purpose:** Enable/configure depth effect (clock behind subject foreground).

**Layout:**
- Same full-bleed wallpaper + live clock preview
- Same bottom panel
- **Depth Effect row:**
  - Label: "Depth Effect" (bold)
  - Sub-label: "The clock sits behind the subject of the wallpaper, like the iOS lock screen."
  - Toggle switch (right-aligned)
- **Preview card:**
  - Rounded dark card showing miniature wallpaper + overlaid clock
  - "PREVIEW" label centered at bottom of card (small, gray, letter-spaced)

**Logic:**
- If `depthEnabled` = true AND wallpaper has a foreground mask, render clock between background and foreground layers
- If `depthEnabled` = true AND wallpaper has no foreground mask, show toast: "Depth effect not available for this wallpaper" and disable the toggle

**Apply button:** Always visible — "✓ Apply Wallpaper"

---

### 5.9 Apply Wallpaper Flow

**Route:** Triggered from Customize or Details screens (bottom sheet or modal)

**Apply options:**
- Home Screen
- Lock Screen
- Both (Home + Lock)

**Implementation:**
1. Present apply destination selector (bottom sheet or dialog)
2. User picks destination
3. Show full-screen progress (loading lottie or spinner over wallpaper)
4. Call native WallpaperChannel → `applyWallpaper(imageBytes, destination, clockConfig, depthConfig)`
5. On success → navigate to Success screen
6. On error → show error state with retry button

**Apply Bottom Sheet layout:**
- Title: "Apply to..."
- Three pill buttons stacked: "Home Screen", "Lock Screen", "Home + Lock Screen"
- Cancel text button

**Success Screen:**
- Full-bleed wallpaper preview thumbnail
- Checkmark animation (Lottie or custom AnimatedContainer)
- "Wallpaper Applied!" headline
- "Your wallpaper has been set successfully." subtext
- "Done" button → pop to Explore

---

### 5.10 Favorites Screen

**Route:** `/favorites`  
**Purpose:** Browse all saved favorite wallpapers.

**Layout:**
1. **Header:** Large title "Favorites" (Display/H1, left-aligned, top padding)
2. **Grid:** 2-column staggered masonry grid
   - Cards: rounded corners, image fill
   - Category label overlaid bottom-left (small, white, slightly transparent bg pill)
   - Heights vary slightly for visual variety (staggered)
   - Name overlaid bottom-left (white, bold, small)
3. **Empty state:** Heart icon + "No favorites yet" + "Tap the heart icon on any wallpaper to save it here" subtext
4. **Bottom nav:** Heart icon active (filled black circle)

**BLoC:** `FavoritesBloc`  
**Events:** `FavoritesFetch`, `FavoriteRemoved(id)`  
**States:** `FavoritesLoading`, `FavoritesLoaded(items)`, `FavoritesEmpty`, `FavoritesError`

---

### 5.11 Settings Screen

**Route:** `/settings`  
**Purpose:** App configuration.

**Layout:**
1. **Header:** Large title "Settings" (Display/H1)
2. **Settings rows** (white card, divider between rows):

| Row | Left | Right |
|-----|------|-------|
| Language | "Language" bold + "App display language" subtext | Two pill buttons: "English" (selected, black fill) / "العربية" |
| Auto-change wallpaper | "Auto-change wallpaper" bold + "A new wallpaper every day" subtext | Toggle (OFF) |
| High quality downloads | "High quality downloads" bold + "Original resolution files" subtext | Toggle (ON) |
| Clear cache | "Clear cache" bold + "42 MB used" subtext (dynamic) | Chevron › |
| About | "About" bold + "Version, licenses & credits" subtext | Chevron › |

3. **Version footer:** "Creative Backgrounds · 1.0.0" centered, small gray text
4. **Bottom nav:** Sun icon active

**Language behavior:**
- Selecting "English" → set locale to `en`
- Selecting "العربية" → set locale to `ar` + RTL layout

**Clear cache behavior:**
- Tapping "Clear cache" row → confirmation dialog → clear Hive cache + image cache → refresh displayed size

**BLoC:** `SettingsBloc`  
**Events:** `SettingsLanguageChanged(locale)`, `SettingsAutoChangeToggled`, `SettingsHQDownloadsToggled`, `SettingsCacheClear`, `SettingsLoaded`  
**States:** `SettingsLoading`, `SettingsLoaded(settings)`, `SettingsCacheClearing`, `SettingsCacheCleared`, `SettingsError`

---

### 5.12 About / Privacy Policy / Terms Screens

**Routes:** `/about`, `/privacy`, `/terms`  
**Purpose:** Static content screens (webview or rich text).

**Layout:**
- Back button + title in app bar
- Scrollable content (WebView for privacy/terms if content is remote URL, or rich text widget for static content)
- App version in About screen

---

## 6. State Management — All Blocs

### 6.1 SplashBloc

```
Events:
  SplashStarted

States:
  SplashInitial
  SplashLoading
  SplashComplete
  SplashError(message)

Flow:
  SplashStarted
    → check connectivity
    → load local settings
    → fetch remote config
    → emit SplashComplete
    → GoRouter redirects to /explore
```

---

### 6.2 ExploreBloc

```
Events:
  ExploreStarted
  ExploreRefreshRequested
  ExploreSectionLoadMore(section)

States:
  ExploreInitial
  ExploreLoading
  ExploreLoaded {
    trending: PaginatedList<WallpaperEntity>
    latest: PaginatedList<WallpaperEntity>
    categories: List<CategoryEntity>
  }
  ExploreError(message)

Behavior:
  - Parallel fetch of trending + latest + categories
  - Each section loads independently
  - Pull-to-refresh triggers ExploreRefreshRequested
```

---

### 6.3 SearchBloc

```
Events:
  SearchQueryChanged(String query)
  SearchCleared
  SearchLoadMoreRequested

States:
  SearchInitial
  SearchLoading
  SearchLoaded(List<WallpaperEntity> results, String query, bool hasMore)
  SearchEmpty(String query)
  SearchError(message)

Behavior:
  - Debounce 300ms on SearchQueryChanged
  - Cancels previous request on new query
  - Persists query history to Hive
```

---

### 6.4 ViewAllBloc

```
Events:
  ViewAllFetchRequested(String section, FilterOptions? filter, SortOption? sort)
  ViewAllLoadMoreRequested
  ViewAllFilterApplied(FilterOptions filter)
  ViewAllSortApplied(SortOption sort)

States:
  ViewAllInitial
  ViewAllLoading
  ViewAllLoaded(List<WallpaperEntity> items, bool hasMore, FilterOptions? activeFilter, SortOption? activeSort)
  ViewAllError(message)
```

---

### 6.5 WallpaperDetailsBloc

```
Events:
  WallpaperDetailsFetchRequested(String id)
  WallpaperFavoriteToggleRequested
  WallpaperShareRequested

States:
  WallpaperDetailsInitial
  WallpaperDetailsLoading
  WallpaperDetailsLoaded(WallpaperEntity wallpaper, bool isFavorite)
  WallpaperDetailsError(message)
  WallpaperFavoriteToggled(bool isFavorite)
  WallpaperSharedSuccess
```

---

### 6.6 CustomizeBloc

```
Events:
  CustomizeTabChanged(ClockEditorTab tab)  // Clock | Styles | Depth
  CustomizeApplyRequested(ApplyDestination destination)

States:
  CustomizeInitial
  CustomizeReady(ClockEditorTab activeTab, ClockConfig clockConfig, DepthConfig depthConfig)
  CustomizeApplying
  CustomizeApplySuccess
  CustomizeApplyError(message)

Note: ClockBloc and DepthBloc are nested within the Customize feature
      and CustomizeBloc orchestrates them for the Apply action.
```

---

### 6.7 ClockBloc

```
Events:
  ClockConfigLoaded
  ClockPositionChanged(ClockPosition position)       // top | center | bottom
  ClockFontChanged(ClockFont font)                   // inter | serif | mono
  ClockColorChanged(Color color)
  ClockSizeChanged(double size)                      // px value 24–120
  ClockOpacityChanged(double opacity)                // 0.0–1.0
  ClockShadowToggled(bool enabled)
  ClockGlowToggled(bool enabled)
  ClockStrokeToggled(bool enabled)
  ClockHourFormatChanged(bool is24Hour)
  ClockDateToggled(bool enabled)
  ClockSecondsToggled(bool enabled)
  ClockStyleChanged(ClockStyle style)
  ClockConfigSaved

States:
  ClockInitial
  ClockReady(ClockConfig config)
  ClockSaving
  ClockSaved

ClockConfig entity:
  position: ClockPosition
  font: ClockFont
  color: Color
  size: double
  opacity: double
  showShadow: bool
  showGlow: bool
  showStroke: bool
  is24Hour: bool
  showDate: bool
  showSeconds: bool
  style: ClockStyle   // Modern | Minimal | Elegant | Digital | ...
```

---

### 6.8 DepthBloc

```
Events:
  DepthConfigLoaded
  DepthEffectToggled(bool enabled)
  DepthConfigSaved

States:
  DepthInitial
  DepthReady(DepthConfig config, bool wallpaperSupportsDepth)
  DepthSaving
  DepthSaved
  DepthNotSupported(WallpaperEntity wallpaper)

DepthConfig entity:
  enabled: bool
  wallpaperId: String
  hasForegroundMask: bool
```

---

### 6.9 ApplyWallpaperBloc

```
Events:
  ApplyWallpaperRequested(ApplyDestination destination, WallpaperEntity wallpaper, ClockConfig? clock, DepthConfig? depth)

States:
  ApplyWallpaperInitial
  ApplyWallpaperInProgress
  ApplyWallpaperSuccess
  ApplyWallpaperError(message)

ApplyDestination enum:
  homeScreen
  lockScreen
  both
```

---

### 6.10 FavoritesBloc

```
Events:
  FavoritesFetchRequested
  FavoriteRemovedRequested(String wallpaperId)
  FavoriteAddedRequested(WallpaperEntity wallpaper)   // dispatched from other features

States:
  FavoritesInitial
  FavoritesLoading
  FavoritesLoaded(List<WallpaperEntity> favorites)
  FavoritesEmpty
  FavoritesError(message)
```

---

### 6.11 SettingsBloc

```
Events:
  SettingsLoadRequested
  SettingsLanguageChanged(String locale)
  SettingsAutoChangeWallpaperToggled
  SettingsHQDownloadsToggled
  SettingsClearCacheRequested
  SettingsAboutOpened

States:
  SettingsInitial
  SettingsLoaded(AppSettings settings)
  SettingsCacheClearing
  SettingsCacheCleared(int freedBytes)
  SettingsError(message)

AppSettings entity:
  language: String         // 'en' | 'ar'
  autoChangeWallpaper: bool
  highQualityDownloads: bool
  cachedSizeBytes: int
  appVersion: String
```

---

### 6.12 ConnectivityBloc

```
Events:
  ConnectivityCheckRequested

States:
  ConnectivityInitial
  ConnectivityOnline
  ConnectivityOffline

Behavior:
  - Subscribes to connectivity stream (connectivity_plus)
  - Emits global offline banner when offline
  - Retries pending requests when back online
```

---

## 7. Navigation Architecture

### 7.1 GoRouter Configuration

```
Route tree:

/                         → SplashPage
/explore                  → ExplorePage (shell route with FloatingBottomNav)
  /explore/search         → SearchPage (appears as overlay/push)
  /explore/view-all/:section → ViewAllPage
  /explore/wallpaper/:id  → WallpaperDetailsPage
    /explore/wallpaper/:id/customize → CustomizePage
/favorites                → FavoritesPage (shell route with FloatingBottomNav)
  /favorites/wallpaper/:id → WallpaperDetailsPage
/settings                 → SettingsPage (shell route with FloatingBottomNav)
  /settings/about         → AboutPage
  /settings/privacy       → PrivacyPolicyPage
  /settings/terms         → TermsPage
```

**Shell Route:** The `FloatingBottomNav` is rendered inside a shell route so it persists across Explore / Favorites / Settings without rebuilding.

### 7.2 Route Parameters

| Route | Parameters |
|-------|-----------|
| `/view-all/:section` | `section`: `trending` \| `latest` \| `all` \| category ID |
| `/wallpaper/:id` | `id`: wallpaper UUID string |
| `/customize/:wallpaperId` | `wallpaperId`: wallpaper UUID |

### 7.3 Navigation Transitions

| Transition | From → To | Type |
|-----------|----------|------|
| Explore → Wallpaper Details | Card tap | Hero + slide-up |
| Details → Customize | Button tap | Bottom-slide-up (sheet-like) |
| Customize → Success | Apply | Fade or custom |
| Bottom nav switch | Tab change | Fade (no slide) |
| View All → Details | Grid tap | Hero + slide |

---

## 8. Clock Engine

### 8.1 Overview

The clock engine has two rendering surfaces:
1. **Flutter Canvas (Preview):** `ClockRendererWidget` uses `CustomPainter` for live preview inside the Customize screen
2. **Native Android Canvas (Live Wallpaper):** `ClockPainter.kt` draws the same clock on the Kotlin side for actual wallpaper application

Both surfaces must produce visually identical output given the same `ClockConfig`.

---

### 8.2 ClockConfig Entity

```
ClockConfig {
  style: ClockStyle          // Modern | Minimal | Elegant | Digital
  position: ClockPosition    // top | center | bottom
  font: ClockFont            // inter | serif | mono
  color: int                 // ARGB color int
  sizePx: double             // 24–120, default 76
  opacity: double            // 0.0–1.0
  showShadow: bool
  showGlow: bool
  showStroke: bool
  is24Hour: bool
  showDate: bool
  showSeconds: bool
}
```

### 8.3 ClockStyle Enum

| Style | Font | Weight | Rendering Notes |
|-------|------|--------|-----------------|
| Modern | Inter | 700 | Clean, tight tracking |
| Minimal | Inter | 300 | Light weight, wide tracking |
| Elegant | Cormorant / PlayfairDisplay | 400 italic | Decorative ligatures |
| Digital | JetBrains Mono | 700 | Fixed-width, colon blink optional |

Additional styles below the visible fold (grid scrolls): at least 2 more from design evidence.

### 8.4 Flutter Clock Renderer (`clock_renderer_widget.dart`)

- `StatefulWidget` wrapping a `CustomPaint` with a `Timer.periodic(Duration(seconds:1))` tick
- Each tick calls `setState` to trigger repaint
- `ClockPainter extends CustomPainter` implements:
  - `drawTime(Canvas, ClockConfig, DateTime)`: formats HH:MM or HH:MM:SS, draws text using `TextPainter`
  - `drawDate(Canvas, ClockConfig, DateTime)`: formats "Monday, July 13", draws below time
  - `applyEffects(Canvas, Paint, ClockConfig)`: applies shadow, glow (using `MaskFilter.blur`), stroke
  - Position calculation: derives y-offset from `ClockPosition` enum and canvas height

### 8.5 Clock Persistence

- `ClockConfig` is serialized to Hive as a JSON map
- Box name: `clock_config`
- Loaded at app start; applied to all rendering surfaces

### 8.6 Platform Channel: Clock

```
Channel name: "com.creative.backgrounds/clock"

Flutter → Native:
  Method: "saveClockConfig"
  Args: Map<String, dynamic> (serialized ClockConfig)

  Method: "clearClockConfig"

Native → Flutter:
  N/A (native reads config from shared storage)
```

### 8.7 Live Wallpaper Clock Rendering (Native)

- `ClockRenderer.kt`: reads `ClockConfig` from `SharedPreferences` (written by Flutter channel)
- Called by `LiveWallpaperService.kt` on each `onDraw(Canvas)` call
- Font loading: `Typeface.createFromAsset(assets, "fonts/inter_bold.ttf")` — fonts are in `android/app/src/main/assets/fonts/`
- Effect pipeline: base text → shadow layer → optional stroke → optional glow (BlurMaskFilter equivalent via Paint.setShadowLayer)
- Invalidate on timer tick: `Handler(Looper.getMainLooper()).postDelayed({ ... }, 1000L)`

---

## 9. Depth Engine

### 9.1 Concept

Depth wallpaper places the clock **behind the foreground subject** of the wallpaper image, mimicking the iOS 16+ lock screen depth effect.

**Requirements:**
- Wallpaper must have a corresponding foreground mask image (PNG with alpha channel separating subject from background)
- If no mask exists, depth effect is disabled for that wallpaper

### 9.2 Layer Stack (bottom to top)

```
Layer 0: Background image (full wallpaper, dimmed slightly if depth active)
Layer 1: Clock (drawn at configured position, depth position between layers)
Layer 2: Foreground mask image (subject PNG with transparency, sits on top of clock)
```

### 9.3 WallpaperEntity — Depth Fields

```
WallpaperEntity {
  ...
  hasForegroundMask: bool
  foregroundMaskUrl: String?    // URL to PNG mask from API
}
```

### 9.4 Flutter Depth Preview (`depth_preview_widget.dart`)

- `Stack` widget with three children:
  1. `CachedNetworkImage` (background)
  2. `ClockRendererWidget` (clock layer)
  3. `CachedNetworkImage` with `foregroundMaskUrl` (foreground, only if `hasForegroundMask`)
- Show "PREVIEW" label overlaid at bottom of preview card

### 9.5 Native Depth Compositor (`DepthCompositor.kt`)

- `compositeWallpaper(background: Bitmap, foreground: Bitmap?, clockConfig: ClockConfig): Bitmap`
- Steps:
  1. Draw background onto canvas
  2. Draw clock text onto canvas (using ClockRenderer)
  3. If foreground != null: draw foreground bitmap on top
  4. Return composed bitmap
- Fallback: if foreground is null and depth is enabled → draw clock normally on top of background

### 9.6 Apply Flow with Depth

```
Flutter:
  1. Download background image bytes (CachedNetworkImage or manual download)
  2. If depth enabled: download foreground mask bytes
  3. Send both to native via WallpaperChannel
  
Native:
  4. Decode bytes → Bitmap
  5. DepthCompositor.compositeWallpaper(...)
  6. WallpaperManager.setBitmap(composed, null, true, WallpaperManager.FLAG_LOCK or FLAG_SYSTEM)
  7. Return success/failure result to Flutter
```

---

## 10. Native Android Modules

### 10.1 WallpaperApplyService.kt

**Purpose:** Apply static wallpaper (bitmap) to home screen, lock screen, or both.

**Platform channel trigger:** Receives method call from `WallpaperChannel.dart`

```
Methods handled:
  "applyWallpaper" → args: { imageUrl, destination, clockConfigJson, depthEnabled, foregroundMaskUrl }
```

**Steps:**
1. Receive args from Flutter
2. Download image on IO dispatcher (if not already cached)
3. Download foreground mask if depthEnabled && url provided
4. Call `DepthCompositor.compositeWallpaper()` if depth enabled
5. Call `WallpaperManager.getInstance(context).setBitmap(bitmap, null, true, flags)` where:
   - `FLAG_LOCK` = lock screen
   - `FLAG_SYSTEM` = home screen
   - both flags combined = both
6. Reply with success `{"status": "success"}` or error `{"status": "error", "message": "..."}`

**Requirements:**
- Run on background thread (Coroutine `Dispatchers.IO`)
- Request `SET_WALLPAPER` permission check before call
- Android 10+: `WallpaperManager.isWallpaperSupported()` check

---

### 10.2 LiveWallpaperService.kt

**Purpose:** Optional live wallpaper service for rendering animated/clock wallpaper.

**Note:** The design shows primarily static wallpaper + clock overlay applied as bitmap. The LiveWallpaperService supports dynamic clock rendering if the wallpaper is set as a live wallpaper.

**Components:**
- `WallpaperService.Engine` subclass
- `onDraw(Canvas)` renders background + clock
- `Handler` triggers redraw every 1000ms for clock tick
- Reads `ClockConfig` from `SharedPreferences`

**Manifest registration:**
```xml
<service android:name=".LiveWallpaperService"
    android:permission="android.permission.BIND_WALLPAPER">
  <intent-filter>
    <action android:name="android.service.wallpaper.WallpaperService" />
  </intent-filter>
  <meta-data android:name="android.service.wallpaper"
      android:resource="@xml/live_wallpaper" />
</service>
```

---

### 10.3 Platform Channels Summary

**Channel: `com.creative.backgrounds/wallpaper`**

| Method (Flutter→Native) | Args | Return |
|------------------------|------|--------|
| `applyWallpaper` | `{url, destination, clockConfig, depthEnabled, maskUrl}` | `{status, message?}` |
| `getWallpaperPermission` | none | `{granted: bool}` |
| `requestWallpaperPermission` | none | `{granted: bool}` |

**Channel: `com.creative.backgrounds/clock`**

| Method (Flutter→Native) | Args | Return |
|------------------------|------|--------|
| `saveClockConfig` | `Map<String,dynamic>` ClockConfig JSON | `{saved: bool}` |
| `clearClockConfig` | none | `{cleared: bool}` |

---

### 10.4 Required Android Permissions

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.SET_WALLPAPER" />
<uses-permission android:name="android.permission.SET_WALLPAPER_HINTS" />
<uses-permission android:name="android.permission.BIND_WALLPAPER" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<!-- READ_EXTERNAL_STORAGE only for Android < 10 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

### 10.5 Battery Optimization

- `LiveWallpaperService` must pause rendering when not visible (`onVisibilityChanged(false)` → cancel handler)
- Clock tick handler uses `Handler.postDelayed` not `Timer` to avoid background wakeup
- Image downloads use `WorkManager` for auto-change wallpaper (if feature enabled)
- Respect `PowerManager.isPowerSaveMode()` → reduce redraw rate to 10s intervals in battery saver

---

## 11. Backend Contract

### 11.1 Authentication

All endpoints require Bearer token authentication:
```
Authorization: Bearer {API_KEY}
```
API key is injected via `.env` file at build time.

### 11.2 Pagination Model

All list endpoints support pagination via query params:

```
GET /endpoint?page=1&limit=20
```

Response envelope:
```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 450,
    "hasMore": true
  }
}
```

---

### 11.3 Endpoint Specifications

#### GET /wallpapers/trending
**Purpose:** Fetch trending wallpapers for home carousel  
**Request:**
```
GET /wallpapers/trending?page=1&limit=10
```
**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "title": "Tokyo Dusk",
      "category": { "id": "uuid", "name": "Neon", "color": "#F5A623" },
      "thumbnailUrl": "https://cdn.example.com/thumbs/tokyo-dusk.jpg",
      "fullUrl": "https://cdn.example.com/full/tokyo-dusk.jpg",
      "resolution": "2160x3840",
      "isPremium": true,
      "hasForegroundMask": false,
      "foregroundMaskUrl": null,
      "downloadCount": 14200,
      "createdAt": "2026-06-01T00:00:00Z"
    }
  ],
  "meta": { "page": 1, "limit": 10, "total": 85, "hasMore": true }
}
```

---

#### GET /wallpapers/latest
**Purpose:** Fetch latest wallpapers for home carousel  
**Request:** `GET /wallpapers/latest?page=1&limit=10`  
**Response:** Same shape as trending

---

#### GET /wallpapers/all
**Purpose:** Fetch all wallpapers with filter + sort support  
**Request:**
```
GET /wallpapers?page=1&limit=20&sort=trending&category=:categoryId&orientation=portrait
```
**Sort values:** `trending` | `latest` | `downloads` | `alphabetical`  
**Orientation values:** `portrait` | `landscape` | `all`

---

#### GET /wallpapers/:id
**Purpose:** Single wallpaper detail  
**Request:** `GET /wallpapers/{id}`  
**Response:**
```json
{
  "id": "uuid",
  "title": "Aurora",
  "category": { "id": "uuid", "name": "Space", "color": "#7B61FF" },
  "thumbnailUrl": "...",
  "fullUrl": "...",
  "resolution": "2160x3840",
  "fileSizeBytes": 8400000,
  "isPremium": false,
  "hasForegroundMask": false,
  "foregroundMaskUrl": null,
  "tags": ["aurora", "night", "sky", "nature"],
  "createdAt": "2026-05-20T00:00:00Z"
}
```

---

#### GET /categories
**Purpose:** All categories for carousels and filters  
**Request:** `GET /categories`  
**Response:**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Nature",
      "thumbnailUrl": "...",
      "wallpaperCount": 120,
      "color": "#4CAF50"
    }
  ]
}
```

---

#### GET /categories/:id/wallpapers
**Purpose:** Wallpapers within a category  
**Request:** `GET /categories/{id}/wallpapers?page=1&limit=20&sort=trending`

---

#### GET /wallpapers/search
**Purpose:** Search wallpapers by keyword  
**Request:**
```
GET /wallpapers/search?q=aurora&page=1&limit=20
```
**Response:** Same shape as wallpaper list

---

#### POST /favorites
**Purpose:** Add wallpaper to favorites  
**Request:**
```json
{ "wallpaperId": "uuid" }
```
**Response:** `{ "success": true }`  
**Note:** Favorites are also stored locally in Hive for offline access

---

#### DELETE /favorites/:wallpaperId
**Purpose:** Remove wallpaper from favorites  
**Response:** `{ "success": true }`

---

#### GET /favorites
**Purpose:** Fetch all favorites for current user  
**Response:** Same shape as wallpaper list (filtered to favorited items)

---

#### GET /config
**Purpose:** Remote app configuration  
**Request:** `GET /config`  
**Response:**
```json
{
  "minimumAppVersion": "1.0.0",
  "maintenanceMode": false,
  "premiumEnabled": true,
  "features": {
    "depthWallpapers": true,
    "liveClock": true,
    "autoChangeWallpaper": true
  }
}
```

---

### 11.4 Error Response Shape

```json
{
  "error": {
    "code": "WALLPAPER_NOT_FOUND",
    "message": "The requested wallpaper does not exist."
  }
}
```

Standard HTTP status codes: 200, 400, 401, 403, 404, 429, 500

---

## 12. Local Storage

### 12.1 Hive Box Definitions

| Box Name | Key | Value Type | Description |
|----------|-----|-----------|-------------|
| `settings` | `language` | String | `'en'` or `'ar'` |
| `settings` | `autoChangeWallpaper` | bool | Auto-change daily toggle |
| `settings` | `highQualityDownloads` | bool | Download HQ toggle |
| `clock_config` | `current` | JSON String | Serialized ClockConfig |
| `favorites` | wallpaperId | JSON String | Serialized WallpaperEntity |
| `recent_wallpapers` | `list` | JSON String | List of last 20 viewed wallpaper IDs |
| `search_history` | `queries` | JSON String | List of last 10 queries |
| `cache_metadata` | `wallpapers_trending` | JSON String | Cached trending list + timestamp |
| `cache_metadata` | `wallpapers_latest` | JSON String | Cached latest list + timestamp |

### 12.2 Cache Invalidation Strategy

- Trending / Latest lists: stale after 30 minutes
- Categories: stale after 24 hours
- Wallpaper details: stale after 1 hour
- On `Clear cache` in Settings: clear all `cache_metadata` box + `CachedNetworkImage` cache

### 12.3 Storage Keys

```dart
// lib/core/storage/storage_keys.dart
class StorageKeys {
  static const language = 'language';
  static const autoChangeWallpaper = 'auto_change_wallpaper';
  static const highQualityDownloads = 'high_quality_downloads';
  static const clockConfig = 'clock_config_current';
  static const favorites = 'favorites';
  static const recentWallpapers = 'recent_wallpapers';
  static const searchHistory = 'search_history';
  static const cacheTrending = 'cache_trending';
  static const cacheLatest = 'cache_latest';
  static const cacheCategories = 'cache_categories';
}
```

---

## 13. Dependency Injection

### 13.1 GetIt Registration (injection.dart)

```
Registration order:

// Core
HiveStorage (singleton)
DioClient (singleton) ← uses BASE_URL, API_KEY from AppConfig
NetworkInfo (singleton)

// Feature: Explore
ExploreRemoteDatasource (lazy singleton) ← DioClient
ExploreRepository (lazy singleton) ← ExploreRemoteDatasource, HiveStorage
GetTrendingWallpapersUseCase (factory) ← ExploreRepository
GetLatestWallpapersUseCase (factory) ← ExploreRepository
GetCategoriesUseCase (factory) ← ExploreRepository
ExploreBloc (factory) ← use cases

// Feature: Search
SearchRemoteDatasource (lazy singleton)
SearchRepository (lazy singleton)
SearchWallpapersUseCase (factory)
SearchBloc (factory)

// Feature: ViewAll
[same pattern]

// Feature: WallpaperDetails
WallpaperDetailsRemoteDatasource (lazy singleton)
WallpaperDetailsRepository (lazy singleton)
GetWallpaperDetailsUseCase (factory)
WallpaperDetailsBloc (factory)

// Feature: Favorites
FavoritesLocalDatasource (lazy singleton) ← HiveStorage
FavoritesRemoteDatasource (lazy singleton) ← DioClient
FavoritesRepository (lazy singleton)
GetFavoritesUseCase, AddFavoriteUseCase, RemoveFavoriteUseCase (factory)
FavoritesBloc (factory)

// Feature: Settings
SettingsLocalDatasource (lazy singleton) ← HiveStorage
SettingsRepository (lazy singleton)
GetSettingsUseCase, UpdateSettingsUseCase (factory)
SettingsBloc (factory)

// Feature: Clock
ClockRepository (lazy singleton) ← HiveStorage
LoadClockConfigUseCase, SaveClockConfigUseCase (factory)
ClockBloc (factory)

// Feature: Depth
DepthRepository (lazy singleton) ← HiveStorage
DepthBloc (factory)

// Platform Channels
WallpaperChannel (singleton)
ClockChannel (singleton)

// Feature: ApplyWallpaper
ApplyWallpaperRepository (lazy singleton) ← WallpaperChannel
ApplyWallpaperUseCase (factory)
ApplyWallpaperBloc (factory)
```

---

## 14. Environment Variables

All environment variables are defined in `.env` at project root and accessed via `flutter_dotenv`.

```
# .env

# API
BASE_URL=https://api.your-backend.com/v1
API_KEY=PLACEHOLDER_API_KEY
IMAGE_BASE_URL=https://cdn.your-backend.com

# Network
TIMEOUT_CONNECT_MS=10000
TIMEOUT_RECEIVE_MS=30000

# Features
ENABLE_PREMIUM=true
ENABLE_DEPTH_WALLPAPERS=true
ENABLE_LIVE_CLOCK=true
ENABLE_AUTO_CHANGE_WALLPAPER=true

# Development
DEBUG_MODE=false
LOGGING_ENABLED=false
MOCK_API=false
```

**Access pattern:**
```dart
// lib/core/config/app_config.dart
class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  static String get apiKey => dotenv.env['API_KEY'] ?? '';
  static String get imageBaseUrl => dotenv.env['IMAGE_BASE_URL'] ?? '';
  static int get connectTimeoutMs => int.parse(dotenv.env['TIMEOUT_CONNECT_MS'] ?? '10000');
  static bool get debugMode => dotenv.env['DEBUG_MODE'] == 'true';
  static bool get loggingEnabled => dotenv.env['LOGGING_ENABLED'] == 'true';
}
```

---

## 15. Android Permissions

### 15.1 Manifest Declarations

```xml
<!-- Required always -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.SET_WALLPAPER" />
<uses-permission android:name="android.permission.SET_WALLPAPER_HINTS" />

<!-- Live wallpaper -->
<uses-permission android:name="android.permission.BIND_WALLPAPER" />

<!-- Auto-change wallpaper (background task) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Notifications (auto-change / download complete) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Storage: Android < 10 only -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

### 15.2 Runtime Permission Flow

| Permission | When Requested | Rationale Shown |
|-----------|---------------|-----------------|
| `SET_WALLPAPER` | On first "Apply Wallpaper" tap | "Creative Backgrounds needs permission to set your wallpaper." |
| `POST_NOTIFICATIONS` | On first auto-change wallpaper enable | "Allow notifications for wallpaper change updates." |
| `READ_EXTERNAL_STORAGE` | Android <10 only, on first apply | "Allow storage access to save your wallpaper." |

---

## 16. Animations

### 16.1 Splash Animation

- **Type:** Fade-in + Scale from 0.8 → 1.0
- **Duration:** 600ms ease-out
- **Target:** App logo/wordmark
- **Implementation:** `AnimatedOpacity` + `TweenAnimationBuilder` or Lottie file

### 16.2 Hero Transition (Card → Details)

- **Type:** Flutter Hero widget, shared image element
- **Hero tag:** `wallpaper_hero_{id}`
- **Image:** `CachedNetworkImage` wrapped in `Hero` on both card and details screen
- **Curve:** `Curves.fastOutSlowIn`, 400ms

### 16.3 Floating Bottom Nav Appear

- **Type:** Fade-in + slide-up from bottom
- **Trigger:** `ScrollController` listener; appears after first 100dp scroll
- **Duration:** 300ms ease-in-out
- **Implementation:** `AnimatedOpacity` + `AnimatedSlide`

### 16.4 Bottom Sheet (Customize Panel)

- **Type:** Slide-up from bottom
- **Implementation:** `DraggableScrollableSheet` with snap points
- **Snap:** 40% height (collapsed), 70% height (expanded)
- **Background blur:** `BackdropFilter` with `ImageFilter.blur(sigmaX: 12, sigmaY: 12)` on panel

### 16.5 Clock Preview Live Update

- **Type:** When any ClockConfig property changes, clock preview updates immediately
- **Cross-fade:** Subtle 200ms cross-fade between previous and new clock rendering states
- **Tick animation:** Clock seconds counter ticks with no animation (instant update as per native clock behavior)

### 16.6 Style Card Selection

- **Type:** Border animates in with scale micro-bounce when selected
- **Duration:** 200ms spring
- **Implementation:** `AnimatedContainer` for border + `Transform.scale` brief 1.0 → 1.03 → 1.0

### 16.7 Favorite Toggle

- **Type:** Heart icon: scale bounce + fill color cross-fade
- **Duration:** 300ms spring
- **Implementation:** `TweenAnimationBuilder` with `SpringSimulation` or `AnimationController` with spring curve

### 16.8 Wallpaper Apply Progress

- **Type:** Full-screen overlay with pulsing spinner or Lottie animation
- **Background:** Semi-transparent dark overlay over wallpaper preview
- **Duration:** Until native callback returns

### 16.9 Success Screen Animation

- **Type:** Checkmark draw-on animation (animated path or Lottie)
- **Sequence:** Overlay fade-in → checkmark draws → headline + button fade up
- **Duration:** Total ~1200ms sequence

### 16.10 Search Bar Expansion

- **Type:** Tapping search bar on Explore → bar expands width + keyboard focus
- **Duration:** 250ms ease-out

---

## 17. Non-Functional Requirements

### 17.1 Performance

| Metric | Target |
|--------|--------|
| Cold start (Splash → Explore) | < 2 seconds on mid-range device |
| Scroll FPS (carousel, grid) | Stable 60 FPS |
| Image load time (thumbnail) | < 500ms on 4G with cache |
| Clock refresh rate | 1 Hz (1 tick per second) |
| API response timeout | 10s connect, 30s receive |

**Implementation:**
- Use `CachedNetworkImage` with `memCacheWidth`/`memCacheHeight` limited to display size
- Use `SliverList` / `SliverGrid` for large lists to avoid off-screen rendering
- Avoid `ImageFilter.blur` on surfaces that scroll; use static frosted panels only

### 17.2 Offline Cache

- App must show last-fetched content when offline
- `ExploreBloc` reads from Hive cache first, then attempts network refresh
- Show persistent `ConnectivityOffline` banner when offline
- Favorites always available offline (local Hive storage)
- Settings always available offline

### 17.3 Memory Optimization

- `CachedNetworkImage` with `maxHeightDiskCache` and `maxWidthDiskCache`
- Clear out-of-viewport image cache on low memory: `imageCache.clear()` in `didHaveMemoryPressure`
- Limit in-memory LRU to 100 MB
- Depth mask images are full-size PNGs — download only when depth is enabled

### 17.4 Security

- HTTPS only (`dio` with certificate pinning optional via `dio_certificate_pinner`)
- API key stored in `.env`, never hardcoded
- No sensitive data in shared preferences
- Hive box encryption for favorites (optional, `hive_flutter` AES)

### 17.5 Localization

- Two languages: English (`en`) and Arabic (`ar`)
- RTL support: `Directionality(textDirection: TextDirection.rtl)` when `ar`
- String table: `lib/core/l10n/app_en.arb` and `app_ar.arb`
- Use `flutter_localizations` + `intl` package
- Date formatting in clock is locale-aware

### 17.6 Accessibility

- Minimum touch target: 48×48 dp for all interactive elements
- Semantic labels on all icon buttons (`Semantics(label: 'Favorite')`)
- `ExcludeSemantics` on purely decorative wallpaper card images
- Text contrast ratio ≥ 4.5:1 for all overlay text

### 17.7 Error Handling

| Error Type | User-Facing Behavior |
|-----------|---------------------|
| No internet | Offline banner + cached content shown |
| API 500 | Error state widget with "Try again" button |
| API 404 (wallpaper) | "Wallpaper not found" screen with back button |
| API 401 | Re-fetch API config; show generic error if persists |
| Wallpaper apply failed | Bottom toast + retry option |
| Image load failed | Placeholder grey card with retry icon |
| Depth mask missing | Depth toggle disabled, tooltip "Not available for this wallpaper" |

---

## 18. Error Handling Strategy

### 18.1 Network Layer

```
DioException → catches in ApiInterceptor:
  - DioExceptionType.connectionTimeout → NetworkTimeoutFailure
  - DioExceptionType.receiveTimeout → NetworkTimeoutFailure
  - DioExceptionType.connectionError → NoInternetFailure
  - Response status 401 → UnauthorizedFailure
  - Response status 404 → NotFoundFailure
  - Response status 500 → ServerFailure
  - Other → UnknownFailure
```

All failures extend abstract `Failure` class and are passed through `Either<Failure, T>` from `dartz` package.

### 18.2 Bloc Error Propagation

```
Repository returns Either<Failure, T>
UseCase folds the Either, maps to domain-level result
Bloc receives result:
  Right(data) → emit Loaded state
  Left(failure) → emit Error state with failure.message
Page listens via BlocBuilder:
  Error state → ErrorWidget with retry callback
```

### 18.3 Connectivity Bloc Integration

`ConnectivityBloc` is provided at root level (above GoRouter's router widget). When `ConnectivityOffline` is emitted, a persistent banner is shown at the top of all screens using `BlocListener` in the root scaffold.

---

*End of Implementation Plan*  
*This document is the single source of truth for Flutter developers, Android native developers, backend developers, and QA engineers.*
