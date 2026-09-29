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

  /// Consecutive app sessions where every ad request failed specifically
  /// with NETWORK_ERROR while general internet connectivity was otherwise
  /// healthy - see AdIntegrityService. Reset to 0 the moment any session
  /// does not reproduce that exact pattern.
  static const adNetworkBlockStreak = 'ad_network_block_streak';

  /// Whether this is the very first time AdIntegrityService has ever run on
  /// this install - a fresh install's first ad request is often slower
  /// (cold SDK init, no cached creative) than steady-state, so it alone gets
  /// one retry before a full-failure counts toward the streak above.
  static const adIntegrityFirstRun = 'ad_integrity_first_run';

  /// Number of wallpapers SUCCESSFULLY applied on this install - the
  /// positive-engagement signal behind the in-app review prompt. Only a
  /// confirmed apply increments it; opening Details, tapping Apply, a
  /// cancelled or failed apply, and a dismissed system picker never do.
  /// See `ReviewService`.
  static const successfulApplyCount = 'successful_apply_count';

  /// App version string that last had a review request handed to Google
  /// Play. Present means "already asked on this version" - the prompt is
  /// never repeated for the same version, regardless of whether Play chose
  /// to actually display its sheet.
  static const reviewRequestedVersion = 'review_requested_version';

  /// ISO-8601 timestamp of the last review request, kept so a future
  /// version's prompt can also respect a minimum spacing between asks.
  static const reviewRequestedAt = 'review_requested_at';

  // clock_config box
  static const clockConfig = 'current';

  // recent_wallpapers box
  static const recentWallpapers = 'list';

  // search_history box
  static const searchHistory = 'queries';

  // cache_metadata box
  static const cacheTrending = 'wallpapers_trending';
  static const cacheLatest = 'wallpapers_latest';

  /// Deliberately distinct from [cacheLatest]: that key may still hold a page
  /// of mixed types written by an earlier build, and serving it into the
  /// live-only section would show normal wallpapers there.
  static const cacheLiveWallpapers = 'wallpapers_live';

  /// Same rationale as [cacheLiveWallpapers]: a distinct key so a depth-only
  /// section never accidentally serves a mixed-type cached page.
  static const cacheDepthWallpapers = 'wallpapers_depth';
  static const cacheCategories = 'categories';

  /// Prefix for a per-category cache slot - the full key is this plus the
  /// category's slug, so each category's Home carousel caches independently
  /// of every other category's.
  static const cacheCategoryWallpapersPrefix = 'wallpapers_category_';

  /// Records which data source produced the cached pages ('mock' | 'live').
  ///
  /// Flipping `MOCK_API` otherwise leaves fixture rows sitting in the cache for
  /// up to 30 minutes - and cached categories for 24 hours - so the app would
  /// keep showing fake content after being pointed at the real backend. On a
  /// mismatch the cache box is dropped at startup.
  static const cacheSourceStamp = 'data_source';
}
