import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two ARB files against drift.
///
/// A key present in English but missing in Arabic does not fail the build - it
/// silently ships an English string to Arabic users, which is exactly the kind
/// of regression that reaches production unnoticed.
void main() {
  Map<String, dynamic> load(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final en = load('lib/core/l10n/app_en.arb');
  final ar = load('lib/core/l10n/app_ar.arb');

  /// Real message keys, excluding ARB `@` metadata and the `@@locale` header.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('Arabic defines every English key', () {
    final missing = messageKeys(en).difference(messageKeys(ar));
    expect(
      missing,
      isEmpty,
      reason: 'these keys would fall back to English for Arabic users: $missing',
    );
  });

  test('Arabic has no orphan keys English does not define', () {
    final orphans = messageKeys(ar).difference(messageKeys(en));
    expect(orphans, isEmpty, reason: 'unused Arabic keys: $orphans');
  });

  group('strings added in this change are translated', () {
    const newKeys = [
      'liveWallpapers',
      'allWallpapers',
      'wallpapers',
      'adBlockClear',
      'adBlockVpnDetected',
      'adBlockDnsSuspicious',
      'adBlockRequestsBlocked',
      'adBlockUnknown',
      'clockHeight',
      'liveWallpaperAppliedToast',
      'liveWallpaperNotAppliedToast',
    ];

    for (final key in newKeys) {
      test('$key exists in both locales', () {
        expect(en[key], isA<String>(), reason: '$key missing from English');
        expect(ar[key], isA<String>(), reason: '$key missing from Arabic');
        expect((en[key] as String).trim(), isNotEmpty);
        expect((ar[key] as String).trim(), isNotEmpty);
      });

      test('$key is actually translated, not copied English', () {
        // A copied English value is the usual symptom of a forgotten
        // translation. Arabic text contains Arabic-script codepoints.
        final arabic = ar[key] as String;
        final hasArabicScript =
            RegExp(r'[؀-ۿ]').hasMatch(arabic);
        expect(
          hasArabicScript,
          isTrue,
          reason: '"$key" Arabic value has no Arabic characters: "$arabic"',
        );
      });
    }
  });

  test('pre-existing section labels are untouched', () {
    // Phase 1 requires Trending to keep its name even though its content
    // source changed.
    expect(en['trending'], 'Trending');
    expect((ar['trending'] as String).trim(), isNotEmpty);
  });
}
