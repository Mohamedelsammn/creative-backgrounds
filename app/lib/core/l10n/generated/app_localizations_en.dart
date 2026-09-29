// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get discoverWallpapers => 'Discover\nWallpapers';

  @override
  String get goodMorning => 'GOOD MORNING';

  @override
  String get goodAfternoon => 'GOOD AFTERNOON';

  @override
  String get goodEvening => 'GOOD EVENING';

  @override
  String get searchPlaceholder => 'Search wallpapers…';

  @override
  String get trending => 'Trending';

  @override
  String get latest => 'Latest';

  @override
  String get viewAll => 'View All';

  @override
  String get favorites => 'Favorites';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'App display language';

  @override
  String get clearCache => 'Clear cache';

  @override
  String cacheUsed(String size) {
    return '$size used';
  }

  @override
  String get clearCacheConfirmTitle => 'Clear cache?';

  @override
  String get clearCacheConfirmBody =>
      'This removes downloaded image data. Wallpapers will re-download when viewed.';

  @override
  String get clearingLabel => 'Clearing…';

  @override
  String get rateApp => 'Rate the app';

  @override
  String get rateAppSubtitle => 'Enjoying Creative Backgrounds?';

  @override
  String get shareApp => 'Share app';

  @override
  String get shareAppSubtitle => 'Tell a friend about Creative Backgrounds';

  @override
  String shareAppMessage(String url) {
    return 'Check out Creative Backgrounds - beautiful wallpapers for your phone: $url';
  }

  @override
  String get storeUnavailable => 'Could not open the Play Store.';

  @override
  String get about => 'About';

  @override
  String get aboutSubtitle => 'Version & credits';

  @override
  String get privacyOptions => 'Privacy Options';

  @override
  String get privacyOptionsSubtitle => 'Manage your ad consent choices';

  @override
  String get searchWallpapers => 'Search wallpapers…';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get madeWithFlutter => 'Made with Flutter';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get privacyBody =>
      'Creative Backgrounds respects your privacy. Wallpapers you favorite and your app preferences are stored only on your device. We do not collect personal information, and applied wallpapers never leave your phone.\n\nImages are streamed from our content delivery network to display and apply wallpapers. Standard, non-identifying request metadata may be processed to serve content.\n\nThis is placeholder content. Replace it with your finalized policy before release.';

  @override
  String get termsBody =>
      'By using Creative Backgrounds you agree to use the wallpapers for personal, non-commercial purposes. Wallpaper content remains the property of its respective creators.\n\nThe app is provided \"as is\" without warranties of any kind. We are not liable for any device-specific issues that arise from applying wallpapers.\n\nThis is placeholder content. Replace it with your finalized terms before release.';

  @override
  String get setAsWallpaperTitle => 'Set as Wallpaper';

  @override
  String get applyTo => 'Choose where you want to apply this wallpaper';

  @override
  String get homeScreen => 'Home Screen';

  @override
  String get lockScreen => 'Lock Screen';

  @override
  String get bothScreens => 'Both';

  @override
  String get homeAndLockScreen => 'Home + Lock Screen';

  @override
  String get setAsLiveWallpaper => 'Set as live wallpaper';

  @override
  String get withDesign => 'With Design';

  @override
  String get wallpaperOnly => 'Wallpaper Only';

  @override
  String get cancel => 'Cancel';

  @override
  String get customize => 'Customize';

  @override
  String get apply => 'Apply';

  @override
  String get applyWallpaper => 'Apply Wallpaper';

  @override
  String get wallpaperApplied => 'Wallpaper Applied!';

  @override
  String get wallpaperAppliedSubtitle =>
      'Your wallpaper has been set successfully.';

  @override
  String get liveWallpaperAppliedToast => 'Live wallpaper applied';

  @override
  String get liveWallpaperNotAppliedToast => 'Wallpaper was not applied';

  @override
  String get done => 'Done';

  @override
  String get depthEffect => 'Depth Effect';

  @override
  String get depthEffectDescription =>
      'The clock sits behind the subject of the wallpaper, like the iOS lock screen.';

  @override
  String get position => 'POSITION';

  @override
  String get font => 'FONT';

  @override
  String get color => 'COLOR';

  @override
  String get size => 'Size';

  @override
  String get clockHeight => 'Stretch';

  @override
  String get opacity => 'Opacity';

  @override
  String get shadow => 'Shadow';

  @override
  String get glow => 'Glow';

  @override
  String get stroke => 'Stroke';

  @override
  String get twentyFourHour => '24-Hour';

  @override
  String get date => 'Date';

  @override
  String get seconds => 'Seconds';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noFavoritesSubtitle =>
      'Tap the heart icon on any wallpaper to save it here.';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clear => 'Clear';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String get retry => 'Retry';

  @override
  String get sortBy => 'Sort by';

  @override
  String get customColor => 'Custom Color';

  @override
  String get specialFeatures => 'Special Features';

  @override
  String get transparentWallpaper => 'Transparent Wallpaper';

  @override
  String get transparentWallpaperSubtitle =>
      'See through your phone with the live rear camera';

  @override
  String get twStatusActive => 'Active';

  @override
  String get twStatusInactive => 'Inactive';

  @override
  String get twStatusUnsupported => 'Unsupported';

  @override
  String get twStatusPreparing => 'Preparing…';

  @override
  String get twStatusPermissionNeeded => 'Permission needed';

  @override
  String get twStatusNeedsAttention => 'Needs attention';

  @override
  String get twContinue => 'Continue';

  @override
  String get twTurnOff => 'Turn off';

  @override
  String get twGrantCameraPermission => 'Grant camera permission';

  @override
  String get twOpenSettings => 'Open settings';

  @override
  String get twPermissionRationale =>
      'This feature uses your rear camera to render a live wallpaper behind your app icons. The camera view stays on your device.';

  @override
  String get twUnsupportedTitle => 'Not supported on this device';

  @override
  String get twCameraPermanentlyDenied =>
      'Camera access is turned off. Enable it in Settings to use this feature.';

  @override
  String get twApply => 'Apply';

  @override
  String twApplyIn(int seconds) {
    return 'Apply in ${seconds}s';
  }

  @override
  String get twCancel => 'Cancel';

  @override
  String get twSettings => 'Settings';

  @override
  String get twPreviewHint =>
      'Preview the live effect, then apply it as your wallpaper.';

  @override
  String get twDisclosureTitle => 'Before you continue';

  @override
  String get twDisclosureBody =>
      'This wallpaper uses your device\'s rear camera to show a live view behind your app icons.\n\n• The camera image is used only on your device to draw the wallpaper — it is never recorded, stored, or shared.\n• While the wallpaper is active, a camera notification and the system camera indicator stay visible.\n• Continuous camera use increases battery consumption.';

  @override
  String get twDisclosureAccept => 'I understand, continue';

  @override
  String get twDisclosureDecline => 'Not now';

  @override
  String get twMsgRunning => 'Your transparent wallpaper is active.';

  @override
  String get twMsgPreparing => 'Setting things up…';

  @override
  String get twMsgApplying => 'Opening the wallpaper picker…';

  @override
  String get twMsgRestoring => 'Restoring your previous wallpaper…';

  @override
  String get twMsgStopped => 'The transparent wallpaper is turned off.';

  @override
  String get twMsgCameraBusy =>
      'The camera is in use by another app. Close it and try again.';

  @override
  String get twMsgCameraLost =>
      'The camera connection was lost. Reopen the wallpaper to retry.';

  @override
  String get twMsgWallpaperRemoved =>
      'The wallpaper was turned off or replaced.';

  @override
  String get twMsgError => 'Something went wrong. Please try again.';

  @override
  String get twRetry => 'Retry';

  @override
  String get twOemWarningTitle => 'This device may need a tweak';

  @override
  String get twBatterySettings => 'Battery settings';

  @override
  String get twQuality => 'Quality';

  @override
  String get twQualitySmooth => 'Smooth';

  @override
  String get twQualityBalanced => 'Balanced';

  @override
  String get twQualitySaver => 'Saver';

  @override
  String get twQualityHint =>
      'Higher quality looks smoother but uses more battery.';

  @override
  String get twRestoreWallpaper => 'Restore previous wallpaper';

  @override
  String get twMsgIncompatible =>
      'Your device can’t run the transparent wallpaper.';

  @override
  String get twMsgStopping => 'Turning off…';

  @override
  String get twMsgRecovering => 'Reconnecting to the camera…';

  @override
  String get twMsgPaused => 'Paused while the screen is off.';

  @override
  String get liveWallpapers => 'Live Wallpapers';

  @override
  String get depthsAndWallpapers => 'Depths & Wallpapers';

  @override
  String get newWallpapers => 'New Wallpapers';

  @override
  String get allWallpapers => 'All';

  @override
  String get wallpapers => 'Wallpapers';

  @override
  String get adBlockClear => 'No network filtering detected.';

  @override
  String get adBlockVpnDetected =>
      'A VPN is active. This may affect some content.';

  @override
  String get adBlockDnsSuspicious =>
      'A filtering DNS service is configured on this device.';

  @override
  String get adBlockRequestsBlocked =>
      'Some network requests appear to be blocked.';

  @override
  String get adBlockUnknown => 'Unable to determine your network status.';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get filter => 'Filter';

  @override
  String get filters => 'Filters';

  @override
  String get categories => 'CATEGORIES';

  @override
  String get reset => 'Reset';

  @override
  String get adsBlockedTitle => 'Ads are required to use this app';

  @override
  String get adsBlockedBody =>
      'It looks like an ad blocker, VPN, or DNS filter is preventing ads from loading. Please disable it and try again.';

  @override
  String get adsBlockedRetry => 'Retry';

  @override
  String get watchAdToApplyTitle => 'Watch an ad to apply';

  @override
  String get watchAdToApplyBody =>
      'This is a PRO wallpaper. Watch a short ad to apply it.';

  @override
  String get watchAd => 'Watch Ad';

  @override
  String get rewardedAdUnavailable =>
      'The ad isn\'t ready yet. Please try again in a moment.';

  @override
  String get updateRequiredTitle => 'Update Required';

  @override
  String get updateRequiredBody =>
      'A new version of Creative Backgrounds is available. Please update to continue.';

  @override
  String get updateNow => 'Update Now';

  @override
  String get couldNotOpenStore => 'Could not open the Play Store.';
}
