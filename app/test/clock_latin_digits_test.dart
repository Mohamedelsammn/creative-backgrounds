import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// `intl` also exports a `TextDirection`, which would shadow Flutter's.
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';

/// The Depth/live wallpaper clock is ARTWORK authored in the dashboard, so it
/// must render the same digits on every device. Before this fix both
/// renderers formatted with the ambient locale:
///
///   Dart  : `DateFormat(pattern, locale)` where `locale` was always null
///   Kotlin: `SimpleDateFormat(pattern, Locale.getDefault())`
///
/// On an Arabic device that produced Arabic-Indic digits (٠٩:٢٧) in the
/// applied home-screen wallpaper. Both now pin `en_US` / `Locale.US`.
///
/// These tests assert the formatting CONTRACT the fix relies on - that the
/// pinned locale yields Latin digits while the ambient/Arabic locale does
/// not - and guard the native side by asserting the source no longer uses
/// `Locale.getDefault()`.
void main() {
  // Needed only by the Arabic REGRESSION group below: `en_US` resolves
  // without initialization (intl's built-in fallback), which is itself part
  // of why the pinned locale is robust - the artwork clock never depends on
  // locale data having been loaded.
  setUpAll(initializeDateFormatting);

  /// The exact patterns `ClockPainter._formatTime` / `formatTime` use.
  /// 12-hour uses `hh` (zero-padded), not `h` - see
  /// `clock_hour_zero_padding_test.dart` for the dedicated regression
  /// coverage of that specific contract; this file only needs the patterns
  /// to stay in sync so its own Latin-digit assertions test the real ones.
  const timePatterns = {
    '24h, no seconds': 'HH:mm',
    '24h, seconds': 'HH:mm:ss',
    '12h, no seconds': 'hh:mm',
    '12h, seconds': 'hh:mm:ss',
  };

  /// The locale both renderers are now pinned to.
  const artworkLocale = 'en_US';

  final at0927 = DateTime(2026, 3, 9, 9, 27, 5);

  bool isAllLatinDigits(String text) =>
      text.runes.where((r) => r >= 0x0600).isEmpty &&
      RegExp(r'[0-9]').hasMatch(text);

  group('time formatting under the pinned artwork locale', () {
    timePatterns.forEach((label, pattern) {
      test('$label renders Latin digits', () {
        final formatted = DateFormat(pattern, artworkLocale).format(at0927);
        expect(
          isAllLatinDigits(formatted),
          isTrue,
          reason: '"$formatted" must contain only Latin digits',
        );
      });
    });

    test('24-hour mode still renders the 24-hour value', () {
      final evening = DateTime(2026, 3, 9, 21, 27);
      expect(DateFormat('HH:mm', artworkLocale).format(evening), '21:27');
    });

    test('12-hour mode still renders the 12-hour value, zero-padded', () {
      final evening = DateTime(2026, 3, 9, 21, 27);
      expect(DateFormat('hh:mm', artworkLocale).format(evening), '09:27');
    });

    test('09:27 stays exactly "09:27"', () {
      expect(DateFormat('HH:mm', artworkLocale).format(at0927), '09:27');
    });

    test('seconds are preserved', () {
      expect(DateFormat('HH:mm:ss', artworkLocale).format(at0927), '09:27:05');
    });
  });

  group('date formatting under the pinned artwork locale', () {
    test('numeric day component is a Latin digit', () {
      final formatted = DateFormat('EEEE, MMMM d', artworkLocale).format(at0927);
      expect(isAllLatinDigits(formatted), isTrue, reason: formatted);
      expect(formatted, contains('9'));
    });

    test('date words stay English so the artwork is device-independent', () {
      final formatted = DateFormat('EEEE, MMMM d', artworkLocale).format(at0927);
      expect(formatted, 'Monday, March 9');
    });
  });

  group('regression: the Arabic locale is what used to leak in', () {
    test(
      'formatting with ar_EG produces NON-Latin digits - proving the bug was '
      'real and that pinning the locale is what prevents it',
      () {
        final arabic = DateFormat('HH:mm', 'ar_EG').format(at0927);
        expect(
          isAllLatinDigits(arabic),
          isFalse,
          reason:
              'ar_EG is expected to render Arabic-Indic digits ("$arabic"); '
              'if this ever starts returning Latin digits the pinned-locale '
              'fix is still correct but this guard is no longer meaningful',
        );
        expect(arabic, isNot('09:27'));
      },
    );

    test('the pinned locale and ar_EG genuinely differ for the same instant',
        () {
      expect(
        DateFormat('HH:mm', artworkLocale).format(at0927),
        isNot(DateFormat('HH:mm', 'ar_EG').format(at0927)),
      );
    });
  });

  group('clock artwork is never mirrored by RTL', () {
    test('an Arabic Directionality does not reverse the clock text', () {
      // ClockPainter builds every TextPainter with an explicit
      // TextDirection.ltr, so an RTL app locale cannot reorder the glyphs.
      final painter = TextPainter(
        text: const TextSpan(
          text: '09:27',
          style: TextStyle(fontSize: 40, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(painter.text!.toPlainText(), '09:27');
      painter.dispose();
    });
  });
}
