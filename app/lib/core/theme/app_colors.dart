import 'package:flutter/material.dart';

/// Reconciled color tokens (light mode only — the only mode in the designs).
///
/// Derived per-token from the screenshots, using DESIGN.md and
/// implementation_plan.md §2.1 as references. The UI palette is strictly
/// achromatic so wallpapers provide all the color; category accents are the
/// only chromatic values and normally come from the API.
class AppColors {
  const AppColors._();

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF2F2F4); // search bar / chip fill
  static const Color surfaceContainer = Color(0xFFF5F3F3);

  // Text
  static const Color textPrimary = Color(0xFF0D0D0D);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textOnImage = Color(0xFFFFFFFF);

  // Brand / interactive (soft black)
  static const Color primary = Color(0xFF0D0D0D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color activeNav = Color(0xFF0D0D0D);

  // Lines
  static const Color divider = Color(0xFFEAEAEC);
  static const Color outline = Color(0xFFC4C7C7);

  // Frosted dark panel (customize sheet). Base color; opacity applied at use.
  static const Color panel = Color(0xFF1E2332);
  static const Color panelGlass = Color(0xB31E2332); // ~70% opacity

  // Chips / segments
  static const Color chipSelected = Color(0xFFFFFFFF);
  static const Color chipUnselected = Color(0x00000000);

  // Feedback
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // Glass overlays on images (frosted circular buttons, gradients)
  static const Color glassLight = Color(0x33FFFFFF);
  static const Color glassDark = Color(0x4D000000);
  static const Color scrim = Color(0x99000000);

  /// Fallback category accent colors keyed by lowercased category name.
  /// Overridden by `CategoryEntity.color` when the API supplies one.
  static const Map<String, Color> categoryAccents = {
    'neon': Color(0xFFF5A623),
    'nature': Color(0xFF4CAF50),
    'dark': Color(0xFF3A7BD5),
    'mountains': Color(0xFF6B8CAE),
    'space': Color(0xFF7B61FF),
    'amoled': Color(0xFF9C6ADE),
  };
}
