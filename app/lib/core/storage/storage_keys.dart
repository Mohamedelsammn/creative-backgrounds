/// Hive box names and the keys used within them.
class HiveBoxes {
  const HiveBoxes._();

  static const settings = 'settings';
  static const clockConfig = 'clock_config';
  static const depthConfig = 'depth_config';
  static const favorites = 'favorites';
  static const recentWallpapers = 'recent_wallpapers';
  static const searchHistory = 'search_history';
  static const cacheMetadata = 'cache_metadata';

  /// All boxes opened at startup by `HiveStorage.init`.
  static const all = <String>[
    settings,
    clockConfig,
    depthConfig,
    favorites,
    recentWallpapers,
    searchHistory,
    cacheMetadata,
  ];
}

class StorageKeys {
  const StorageKeys._();

  // settings box
  static const language = 'language';
  static const transparentDisclosureAccepted = 'transparent_disclosure_accepted';

  // clock_config box
  static const clockConfig = 'current';

  // recent_wallpapers box
  static const recentWallpapers = 'list';

  // search_history box
  static const searchHistory = 'queries';

  // cache_metadata box
  static const cacheTrending = 'wallpapers_trending';
  static const cacheLatest = 'wallpapers_latest';
  static const cacheCategories = 'categories';
}
