import 'package:flutter/material.dart';

/// Corner-radius tokens (reconciled: grid cards ~16, hero cards & panels ~24,
/// interactive elements are pills).
class AppRadii {
  const AppRadii._();

  static const double sm = 12;
  static const double card = 16; // grid / thumbnail cards
  static const double cardLarge = 24; // hero carousel cards
  static const double panel = 24; // bottom sheets / info panels
  static const double pill = 999;
}

class AppShapes {
  const AppShapes._();

  static final BorderRadius card = BorderRadius.circular(AppRadii.card);
  static final BorderRadius cardLarge = BorderRadius.circular(AppRadii.cardLarge);
  static final BorderRadius panel = BorderRadius.circular(AppRadii.panel);
  static final BorderRadius pill = BorderRadius.circular(AppRadii.pill);

  /// Top-rounded radius for bottom sheets / info panels.
  static const BorderRadius panelTop = BorderRadius.only(
    topLeft: Radius.circular(AppRadii.panel),
    topRight: Radius.circular(AppRadii.panel),
  );

  static final RoundedRectangleBorder cardBorder =
      RoundedRectangleBorder(borderRadius: card);
  static final RoundedRectangleBorder pillBorder =
      RoundedRectangleBorder(borderRadius: pill);
}
