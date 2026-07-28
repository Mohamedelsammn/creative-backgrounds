/// Centralized route paths and names for GoRouter.
///
/// Shell tabs (`/explore`, `/favorites`, `/settings`) keep the persistent
/// floating bottom nav. Details / Customize / Search / Success are full-screen
/// pushes *outside* the shell (no bottom nav), per the screenshots.
class RouteNames {
  const RouteNames._();

  // Splash
  static const splash = '/';

  // Shell tabs
  static const explore = '/explore';
  static const favorites = '/favorites';
  static const settings = '/settings';

  // Full-screen pushes
  static const search = '/search';
  static const viewAll = '/view-all/:section';
  static const wallpaperDetails = '/wallpaper/:id';
  static const customize = '/customize/:wallpaperId';
  static const success = '/success';

  // Transparent (live rear-camera) wallpaper
  static const transparentPreview = '/transparent/preview';
  static const transparentSettings = '/transparent/settings';

  // Static content
  static const about = '/about';
  static const privacy = '/privacy';
  static const terms = '/terms';

  // Helpers to build concrete paths
  static String viewAllPath(String section) => '/view-all/$section';
  static String wallpaperDetailsPath(String id) => '/wallpaper/$id';
  static String customizePath(String wallpaperId) => '/customize/$wallpaperId';
}
