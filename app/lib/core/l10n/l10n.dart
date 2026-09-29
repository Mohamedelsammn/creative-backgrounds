import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Convenience accessor: `context.l10n.settings`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The active language code ('en' / 'ar').
  ///
  /// Backend content is bilingual (categories carry `nameEn` and `nameAr`), so
  /// content strings need the locale the same way UI strings do.
  String get languageCode => Localizations.localeOf(this).languageCode;
}
