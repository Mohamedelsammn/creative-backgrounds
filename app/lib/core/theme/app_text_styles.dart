import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Inter-based type scale (per implementation_plan.md §2.1, reconciled with the
/// screenshots). Clock display styles are handled separately by the clock
/// engine, which swaps font families per clock style.
class AppTextStyles {
  const AppTextStyles._();

  static const String fontFamily = 'Inter';

  /// Page titles: "Discover Wallpapers", "Favorites", "Settings".
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 25,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  /// Eyebrow: "GOOD MORNING".
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textSecondary,
  );

  /// Section headers: "Trending", "Latest", "Nature".
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Settings row label; primary button text.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Card titles, general body.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Settings subtitles.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Card category, version footer.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Bold white card title overlaid on images.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnImage,
  );

  /// Small white card subtitle overlaid on images.
  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnImage,
  );

  /// Uppercase panel labels: "POSITION", "FONT", "COLOR".
  static const TextStyle panelLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Colors.white70,
  );
}
