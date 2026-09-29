import '../config/app_config.dart';

/// Google AdMob identifiers for Creative Backgrounds.
///
/// Every getter here returns Google's OFFICIAL TEST ad unit ID unless
/// [AppConfig.useRealAdUnits] is true (a `--release` build, without the
/// `FORCE_TEST_ADS` escape hatch) - see that getter's doc for why the switch
/// is compile-mode-driven rather than a `.env` toggle. Serving the real IDs
/// during development risks the AdMob account being flagged for invalid
/// traffic (a developer's own repeated impressions/clicks); test IDs always
/// serve Google's clearly-labeled "Test Ad" creative and never bill or count
/// against real inventory.
///
/// The AndroidManifest's `com.google.android.gms.ads.APPLICATION_ID`
/// meta-data is a SEPARATE thing this class cannot control - it is read by
/// the native SDK before Dart starts, so it cannot follow this same runtime
/// switch. `android/app/src/release/AndroidManifest.xml` overrides it with
/// the real App ID (ca-app-pub-6633902647647422~4498366369) automatically
/// via the Gradle manifest merge for every release build - see that file and
/// the comment beside the test value in `main/AndroidManifest.xml`.
class AdConstants {
  AdConstants._();

  // ── Google's official public test IDs (Android) ──────────────────────
  // https://developers.google.com/admob/android/test-ads
  // The test App ID (ca-app-pub-3940256099942544~3347511713) has no Dart-side
  // constant since it's manifest-only - see AndroidManifest.xml's own copy.
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── Real, revenue-generating IDs (this app's AdMob account) ───────────
  // Only ever returned when AppConfig.useRealAdUnits is true. Never call
  // these directly - always go through the public getters below.
  //
  // The real App ID (ca-app-pub-6633902647647422~4498366369) has no
  // Dart-side constant for the same reason as the test one above - see
  // AndroidManifest.xml's own copy and its "swap before release" comment.
  static const String _realAppOpenAdUnitId =
      'ca-app-pub-6633902647647422/3877253524';
  static const String _realInterstitialAdUnitId =
      'ca-app-pub-6633902647647422/7090840305';
  static const String _realBottomBannerAdUnitId =
      'ca-app-pub-6633902647647422/8023668088';
  static const String _realTopBannerAdUnitId =
      'ca-app-pub-6633902647647422/5122172575';
  static const String _realInFeedBannerAdUnitId =
      'ca-app-pub-6633902647647422/2496009235';
  static const String _realRewardedAdUnitId =
      'ca-app-pub-6633902647647422/8869845899';

  /// App Open Ad - shown once per app session, right after Splash clears.
  static String get appOpenAdUnitId =>
      AppConfig.useRealAdUnits ? _realAppOpenAdUnitId : _testAppOpenAdUnitId;

  /// Interstitial Ad - shown periodically while browsing (see AdManager).
  static String get interstitialAdUnitId => AppConfig.useRealAdUnits
      ? _realInterstitialAdUnitId
      : _testInterstitialAdUnitId;

  /// Bottom anchor banner - View All page, and Category Details' single
  /// persistent banner below the wallpaper grid.
  static String get bottomBannerAdUnitId => AppConfig.useRealAdUnits
      ? _realBottomBannerAdUnitId
      : _testBannerAdUnitId;

  /// Top banner - the first between-sections banner on Home.
  static String get topBannerAdUnitId =>
      AppConfig.useRealAdUnits ? _realTopBannerAdUnitId : _testBannerAdUnitId;

  /// In-feed banner - subsequent between-sections banners on Home.
  static String get inFeedBannerAdUnitId => AppConfig.useRealAdUnits
      ? _realInFeedBannerAdUnitId
      : _testBannerAdUnitId;

  /// Rewarded Ad - watched to unlock applying a PRO wallpaper.
  static String get rewardedAdUnitId =>
      AppConfig.useRealAdUnits ? _realRewardedAdUnitId : _testRewardedAdUnitId;
}
