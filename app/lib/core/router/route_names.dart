/// Centralized route paths and names for GoRouter.
///
/// Shell tabs (`/explore`, `/categories`, `/favorites`, `/settings`) keep the
/// persistent floating bottom nav. Details / Category Details / Search /
/// Success are full-screen pushes *outside* the shell (no bottom nav).
class RouteNames {
  const RouteNames._();

  // Splash
  static const splash = '/';

  // Shell tabs
  static const explore = '/explore';
  static const categories = '/categories';
  static const favorites = '/favorites';
  static const settings = '/settings';

  // Full-screen pushes
  static const search = '/search';
  static const wallpaperDetails = '/wallpaper/:id';
  static const categoryDetails = '/categories/:slug';
  static const success = '/success';

  // Transparent (live rear-camera) wallpaper
  static const transparentPreview = '/transparent/preview';
  static const transparentSettings = '/transparent/settings';

  // Static content
  static const about = '/about';
  static const privacy = '/privacy';
  static const terms = '/terms';

  // Helpers to build concrete paths
  static String wallpaperDetailsPath(String id) => '/wallpaper/$id';
  static String categoryDetailsPath(String slug) => '/categories/$slug';
}
