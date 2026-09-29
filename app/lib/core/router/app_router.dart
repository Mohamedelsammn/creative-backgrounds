import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/apply_wallpaper/presentation/pages/success_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/categories/presentation/pages/category_details_page.dart';
import '../../features/explore/domain/entities/category_entity.dart';
import '../../features/explore/presentation/pages/explore_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/privacy_policy_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/terms_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/transparent_wallpaper/presentation/pages/transparent_preview_page.dart';
import '../../features/transparent_wallpaper/presentation/pages/transparent_settings_page.dart';
import '../../features/explore/domain/entities/wallpaper_entity.dart';
import '../../features/wallpaper_details/presentation/pages/wallpaper_details_page.dart';
import 'main_shell.dart';
import 'route_names.dart';

/// Central GoRouter configuration.
///
/// The four primary tabs live in a [StatefulShellRoute] so the floating bottom
/// nav persists across them. Details / Category Details / Search / Success
/// are full-screen pushes outside the shell (no bottom nav).
class AppRouter {
  const AppRouter._();

  static GoRouter build() {
    return GoRouter(
      initialLocation: RouteNames.splash,
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.explore,
                  builder: (context, state) => const ExplorePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.categories,
                  builder: (context, state) => const CategoriesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.favorites,
                  builder: (context, state) => const FavoritesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.settings,
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: RouteNames.search,
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: RouteNames.wallpaperDetails,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: WallpaperDetailsPage(
              id: state.pathParameters['id']!,
              knownWallpaper: state.extra is WallpaperEntity
                  ? state.extra as WallpaperEntity
                  : null,
            ),
            // A short fade + subtle scale, replacing the previous shared-element
            // Hero. The Hero flight lifted the image into the route overlay,
            // leaving the destination's black Scaffold visible for the whole
            // flight; the Trending carousel also loops infinitely and rendered
            // duplicate Hero tags in one tree. This transition keeps both
            // screens painted throughout, so there is no black frame in either
            // direction, and the destination's cached thumbnail is already on
            // screen when the fade begins.
            // Details is visually opaque. Marking the route accordingly lets
            // Flutter stop painting Home (images, banners and any live poster)
            // underneath it as soon as the transition completes.
            opaque: true,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  // Starts fractionally small so it reads as the card growing
                  // into place, without the cost of a real shared element.
                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: RouteNames.categoryDetails,
          builder: (context, state) => CategoryDetailsPage(
            slug: state.pathParameters['slug']!,
            knownCategory: state.extra is CategoryEntity
                ? state.extra as CategoryEntity
                : null,
          ),
        ),
        GoRoute(
          path: RouteNames.success,
          builder: (context, state) => const SuccessPage(),
        ),
        GoRoute(
          path: RouteNames.transparentPreview,
          builder: (context, state) => const TransparentPreviewPage(),
        ),
        GoRoute(
          path: RouteNames.transparentSettings,
          builder: (context, state) => const TransparentSettingsPage(),
        ),
        GoRoute(
          path: RouteNames.about,
          builder: (context, state) => const AboutPage(),
        ),
        GoRoute(
          path: RouteNames.privacy,
          builder: (context, state) => const PrivacyPolicyPage(),
        ),
        GoRoute(
          path: RouteNames.terms,
          builder: (context, state) => const TermsPage(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Page not found: ${state.uri}')),
      ),
    );
  }
}
