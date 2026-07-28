import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/apply_wallpaper/presentation/pages/success_page.dart';
import '../../features/customize/presentation/pages/customize_page.dart';
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
import '../../features/view_all/presentation/pages/view_all_page.dart';
import '../../features/wallpaper_details/presentation/pages/wallpaper_details_page.dart';
import 'main_shell.dart';
import 'route_names.dart';

/// Central GoRouter configuration.
///
/// The three primary tabs live in a [StatefulShellRoute] so the floating bottom
/// nav persists across them. Details / Customize / Search / Success are
/// full-screen pushes outside the shell (no bottom nav).
///
/// Pages not yet implemented render a [_PlaceholderPage]; each is swapped for
/// the real page as its feature is built.
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
          path: RouteNames.viewAll,
          builder: (context, state) =>
              ViewAllPage(section: state.pathParameters['section']!),
        ),
        GoRoute(
          path: RouteNames.wallpaperDetails,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: WallpaperDetailsPage(
              id: state.pathParameters['id']!,
              heroTag: state.extra as String?,
            ),
            // Pure Hero: the image grows seamlessly from the tapped card into the
            // Details page. No page-level fade or slide — the destination paints
            // immediately and the shared-element Hero flight is the only motion.
            // The route duration drives the Hero flight timing.
            opaque: true,
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                child,
          ),
        ),
        GoRoute(
          path: RouteNames.customize,
          builder: (context, state) => CustomizePage(
              wallpaperId: state.pathParameters['wallpaperId']!),
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
