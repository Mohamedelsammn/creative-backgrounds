import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @discoverWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Discover\nWallpapers'**
  String get discoverWallpapers;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'GOOD MORNING'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'GOOD AFTERNOON'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'GOOD EVENING'**
  String get goodEvening;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search wallpapers…'**
  String get searchPlaceholder;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get languageSubtitle;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @cacheUsed.
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String cacheUsed(String size);

  /// No description provided for @clearCacheConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get clearCacheConfirmTitle;

  /// No description provided for @clearCacheConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes downloaded image data. Wallpapers will re-download when viewed.'**
  String get clearCacheConfirmBody;

  /// No description provided for @clearingLabel.
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get clearingLabel;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get rateApp;

  /// No description provided for @rateAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying Creative Backgrounds?'**
  String get rateAppSubtitle;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareApp;

  /// No description provided for @shareAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell a friend about Creative Backgrounds'**
  String get shareAppSubtitle;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out Creative Backgrounds - beautiful wallpapers for your phone: {url}'**
  String shareAppMessage(String url);

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Play Store.'**
  String get storeUnavailable;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version & credits'**
  String get aboutSubtitle;

  /// No description provided for @privacyOptions.
  ///
  /// In en, this message translates to:
  /// **'Privacy Options'**
  String get privacyOptions;

  /// No description provided for @privacyOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your ad consent choices'**
  String get privacyOptionsSubtitle;

  /// No description provided for @searchWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Search wallpapers…'**
  String get searchWallpapers;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @madeWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Made with Flutter'**
  String get madeWithFlutter;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Creative Backgrounds respects your privacy. Wallpapers you favorite and your app preferences are stored only on your device. We do not collect personal information, and applied wallpapers never leave your phone.\n\nImages are streamed from our content delivery network to display and apply wallpapers. Standard, non-identifying request metadata may be processed to serve content.\n\nThis is placeholder content. Replace it with your finalized policy before release.'**
  String get privacyBody;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'By using Creative Backgrounds you agree to use the wallpapers for personal, non-commercial purposes. Wallpaper content remains the property of its respective creators.\n\nThe app is provided \"as is\" without warranties of any kind. We are not liable for any device-specific issues that arise from applying wallpapers.\n\nThis is placeholder content. Replace it with your finalized terms before release.'**
  String get termsBody;

  /// No description provided for @setAsWallpaperTitle.
  ///
  /// In en, this message translates to:
  /// **'Set as Wallpaper'**
  String get setAsWallpaperTitle;

  /// No description provided for @applyTo.
  ///
  /// In en, this message translates to:
  /// **'Choose where you want to apply this wallpaper'**
  String get applyTo;

  /// No description provided for @homeScreen.
  ///
  /// In en, this message translates to:
  /// **'Home Screen'**
  String get homeScreen;

  /// No description provided for @lockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock Screen'**
  String get lockScreen;

  /// No description provided for @bothScreens.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get bothScreens;

  /// No description provided for @homeAndLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Home + Lock Screen'**
  String get homeAndLockScreen;

  /// No description provided for @setAsLiveWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as live wallpaper'**
  String get setAsLiveWallpaper;

  /// No description provided for @withDesign.
  ///
  /// In en, this message translates to:
  /// **'With Design'**
  String get withDesign;

  /// No description provided for @wallpaperOnly.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper Only'**
  String get wallpaperOnly;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applyWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Apply Wallpaper'**
  String get applyWallpaper;

  /// No description provided for @wallpaperApplied.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper Applied!'**
  String get wallpaperApplied;

  /// No description provided for @wallpaperAppliedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper has been set successfully.'**
  String get wallpaperAppliedSubtitle;

  /// No description provided for @liveWallpaperAppliedToast.
  ///
  /// In en, this message translates to:
  /// **'Live wallpaper applied'**
  String get liveWallpaperAppliedToast;

  /// No description provided for @liveWallpaperNotAppliedToast.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper was not applied'**
  String get liveWallpaperNotAppliedToast;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @depthEffect.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect'**
  String get depthEffect;

  /// No description provided for @depthEffectDescription.
  ///
  /// In en, this message translates to:
  /// **'The clock sits behind the subject of the wallpaper, like the iOS lock screen.'**
  String get depthEffectDescription;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'POSITION'**
  String get position;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'FONT'**
  String get font;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'COLOR'**
  String get color;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @clockHeight.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get clockHeight;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @shadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get shadow;

  /// No description provided for @glow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get glow;

  /// No description provided for @stroke.
  ///
  /// In en, this message translates to:
  /// **'Stroke'**
  String get stroke;

  /// No description provided for @twentyFourHour.
  ///
  /// In en, this message translates to:
  /// **'24-Hour'**
  String get twentyFourHour;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any wallpaper to save it here.'**
  String get noFavoritesSubtitle;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @specialFeatures.
  ///
  /// In en, this message translates to:
  /// **'Special Features'**
  String get specialFeatures;

  /// No description provided for @transparentWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Transparent Wallpaper'**
  String get transparentWallpaper;

  /// No description provided for @transparentWallpaperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See through your phone with the live rear camera'**
  String get transparentWallpaperSubtitle;

  /// No description provided for @twStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get twStatusActive;

  /// No description provided for @twStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get twStatusInactive;

  /// No description provided for @twStatusUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get twStatusUnsupported;

  /// No description provided for @twStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get twStatusPreparing;

  /// No description provided for @twStatusPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get twStatusPermissionNeeded;

  /// No description provided for @twStatusNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get twStatusNeedsAttention;

  /// No description provided for @twContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get twContinue;

  /// No description provided for @twTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get twTurnOff;

  /// No description provided for @twGrantCameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant camera permission'**
  String get twGrantCameraPermission;

  /// No description provided for @twOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get twOpenSettings;

  /// No description provided for @twPermissionRationale.
  ///
  /// In en, this message translates to:
  /// **'This feature uses your rear camera to render a live wallpaper behind your app icons. The camera view stays on your device.'**
  String get twPermissionRationale;

  /// No description provided for @twUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not supported on this device'**
  String get twUnsupportedTitle;

  /// No description provided for @twCameraPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is turned off. Enable it in Settings to use this feature.'**
  String get twCameraPermanentlyDenied;

  /// No description provided for @twApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get twApply;

  /// No description provided for @twApplyIn.
  ///
  /// In en, this message translates to:
  /// **'Apply in {seconds}s'**
  String twApplyIn(int seconds);

  /// No description provided for @twCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get twCancel;

  /// No description provided for @twSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get twSettings;

  /// No description provided for @twPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Preview the live effect, then apply it as your wallpaper.'**
  String get twPreviewHint;

  /// No description provided for @twDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get twDisclosureTitle;

  /// No description provided for @twDisclosureBody.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper uses your device\'s rear camera to show a live view behind your app icons.\n\n• The camera image is used only on your device to draw the wallpaper — it is never recorded, stored, or shared.\n• While the wallpaper is active, a camera notification and the system camera indicator stay visible.\n• Continuous camera use increases battery consumption.'**
  String get twDisclosureBody;

  /// No description provided for @twDisclosureAccept.
  ///
  /// In en, this message translates to:
  /// **'I understand, continue'**
  String get twDisclosureAccept;

  /// No description provided for @twDisclosureDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get twDisclosureDecline;

  /// No description provided for @twMsgRunning.
  ///
  /// In en, this message translates to:
  /// **'Your transparent wallpaper is active.'**
  String get twMsgRunning;

  /// No description provided for @twMsgPreparing.
  ///
  /// In en, this message translates to:
  /// **'Setting things up…'**
  String get twMsgPreparing;

  /// No description provided for @twMsgApplying.
  ///
  /// In en, this message translates to:
  /// **'Opening the wallpaper picker…'**
  String get twMsgApplying;

  /// No description provided for @twMsgRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring your previous wallpaper…'**
  String get twMsgRestoring;

  /// No description provided for @twMsgStopped.
  ///
  /// In en, this message translates to:
  /// **'The transparent wallpaper is turned off.'**
  String get twMsgStopped;

  /// No description provided for @twMsgCameraBusy.
  ///
  /// In en, this message translates to:
  /// **'The camera is in use by another app. Close it and try again.'**
  String get twMsgCameraBusy;

  /// No description provided for @twMsgCameraLost.
  ///
  /// In en, this message translates to:
  /// **'The camera connection was lost. Reopen the wallpaper to retry.'**
  String get twMsgCameraLost;

  /// No description provided for @twMsgWallpaperRemoved.
  ///
  /// In en, this message translates to:
  /// **'The wallpaper was turned off or replaced.'**
  String get twMsgWallpaperRemoved;

  /// No description provided for @twMsgError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get twMsgError;

  /// No description provided for @twRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get twRetry;

  /// No description provided for @twOemWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This device may need a tweak'**
  String get twOemWarningTitle;

  /// No description provided for @twBatterySettings.
  ///
  /// In en, this message translates to:
  /// **'Battery settings'**
  String get twBatterySettings;

  /// No description provided for @twQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get twQuality;

  /// No description provided for @twQualitySmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get twQualitySmooth;

  /// No description provided for @twQualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get twQualityBalanced;

  /// No description provided for @twQualitySaver.
  ///
  /// In en, this message translates to:
  /// **'Saver'**
  String get twQualitySaver;

  /// No description provided for @twQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Higher quality looks smoother but uses more battery.'**
  String get twQualityHint;

  /// No description provided for @twRestoreWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Restore previous wallpaper'**
  String get twRestoreWallpaper;

  /// No description provided for @twMsgIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Your device can’t run the transparent wallpaper.'**
  String get twMsgIncompatible;

  /// No description provided for @twMsgStopping.
  ///
  /// In en, this message translates to:
  /// **'Turning off…'**
  String get twMsgStopping;

  /// No description provided for @twMsgRecovering.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to the camera…'**
  String get twMsgRecovering;

  /// No description provided for @twMsgPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused while the screen is off.'**
  String get twMsgPaused;

  /// No description provided for @liveWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Live Wallpapers'**
  String get liveWallpapers;

  /// No description provided for @depthsAndWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Depths & Wallpapers'**
  String get depthsAndWallpapers;

  /// No description provided for @newWallpapers.
  ///
  /// In en, this message translates to:
  /// **'New Wallpapers'**
  String get newWallpapers;

  /// No description provided for @allWallpapers.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allWallpapers;

  /// No description provided for @wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers'**
  String get wallpapers;

  /// No description provided for @adBlockClear.
  ///
  /// In en, this message translates to:
  /// **'No network filtering detected.'**
  String get adBlockClear;

  /// No description provided for @adBlockVpnDetected.
  ///
  /// In en, this message translates to:
  /// **'A VPN is active. This may affect some content.'**
  String get adBlockVpnDetected;

  /// No description provided for @adBlockDnsSuspicious.
  ///
  /// In en, this message translates to:
  /// **'A filtering DNS service is configured on this device.'**
  String get adBlockDnsSuspicious;

  /// No description provided for @adBlockRequestsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Some network requests appear to be blocked.'**
  String get adBlockRequestsBlocked;

  /// No description provided for @adBlockUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine your network status.'**
  String get adBlockUnknown;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'CATEGORIES'**
  String get categories;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @adsBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ads are required to use this app'**
  String get adsBlockedTitle;

  /// No description provided for @adsBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'It looks like an ad blocker, VPN, or DNS filter is preventing ads from loading. Please disable it and try again.'**
  String get adsBlockedBody;

  /// No description provided for @adsBlockedRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adsBlockedRetry;

  /// No description provided for @watchAdToApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to apply'**
  String get watchAdToApplyTitle;

  /// No description provided for @watchAdToApplyBody.
  ///
  /// In en, this message translates to:
  /// **'This is a PRO wallpaper. Watch a short ad to apply it.'**
  String get watchAdToApplyBody;

  /// No description provided for @watchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAd;

  /// No description provided for @rewardedAdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The ad isn\'t ready yet. Please try again in a moment.'**
  String get rewardedAdUnavailable;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of Creative Backgrounds is available. Please update to continue.'**
  String get updateRequiredBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @couldNotOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Play Store.'**
  String get couldNotOpenStore;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
