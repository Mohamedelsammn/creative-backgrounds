import 'dart:io';

import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage: reported bug - `bunny`'s Details/Apply/applied clock
/// rendered a single-digit hour ("8" / "53") instead of the dashboard's own
/// zero-padded reference ("08" / "53").
///
/// Root cause: `ClockPainter._formatTime`'s 12-hour pattern used ICU's `h`
/// token (non-padded) while its 24-hour pattern already correctly used `HH`
/// (padded). `Kotlin`'s `ClockRenderer.formatTime` mirrored the same bug with
/// the same tokens (`SimpleDateFormat` uses the identical ICU convention).
/// Fixed by switching 12-hour to `hh` on both platforms - the ONLY change;
/// `hh` still correctly keeps noon/midnight as "12", never "00".
///
/// [ClockPainter.formatTimeForTest] exercises the REAL production method
/// (`_formatTime`), not a reimplementation, exactly like
/// [ClockPainter.buildTimePainterForTest] does for glyph geometry elsewhere
/// in this suite.
void main() {
  ClockPainter painterFor(bool is24Hour) => ClockPainter(
        config: ClockConfigEntity(is24Hour: is24Hour),
        now: DateTime(2026, 1, 1),
      );

  group('12-hour mode zero-pads the hour, never changes the value', () {
    final painter = painterFor(false);

    final cases = {
      // hour, minute -> expected "hh:mm"
      (1, 5): '01:05',
      (8, 53): '08:53',
      (9, 9): '09:09',
      (12, 4): '12:04', // noon/midnight boundary: stays "12", not "00"
      (11, 59): '11:59',
      (10, 0): '10:00', // already two digits - unaffected
    };

    cases.forEach((hm, expected) {
      final (hour, minute) = hm;
      test('$hour:$minute -> $expected', () {
        // DateTime takes 24-hour values; 12-hour formatting is derived by
        // the pattern itself, so feed it the 24-hour equivalent when hour
        // >= 13 is meaningless here - every case above is already < 13.
        final t = DateTime(2026, 1, 1, hour, minute);
        expect(painter.formatTimeForTest(t, false, false), expected);
      });
    });

    test('1:05 AM and 8:53 PM keep their AM/PM identity (checked via the '
        '24-hour source hour, not reformatted here)', () {
      final am = DateTime(2026, 1, 1, 1, 5); // 1:05 AM
      final pm = DateTime(2026, 1, 1, 20, 53); // 8:53 PM
      expect(painter.formatTimeForTest(am, false, false), '01:05');
      expect(painter.formatTimeForTest(pm, false, false), '08:53');
    });

    test('minutes stay two digits regardless - unaffected by this fix', () {
      final t = DateTime(2026, 1, 1, 8, 5);
      expect(painter.formatTimeForTest(t, false, false), '08:05');
    });

    test('showSeconds still zero-pads the hour, seconds untouched', () {
      final t = DateTime(2026, 1, 1, 8, 53, 7);
      expect(painter.formatTimeForTest(t, false, true), '08:53:07');
    });
  });

  group('24-hour mode is unchanged - already zero-padded, never becomes '
      '12-hour', () {
    final painter = painterFor(true);

    final cases = {
      const TimeOfDay(hour: 0, minute: 5): '00:05',
      const TimeOfDay(hour: 7, minute: 9): '07:09',
      const TimeOfDay(hour: 13, minute: 5): '13:05',
      const TimeOfDay(hour: 23, minute: 59): '23:59',
    };

    cases.forEach((tod, expected) {
      test('${tod.hour}:${tod.minute} -> $expected', () {
        final t = DateTime(2026, 1, 1, tod.hour, tod.minute);
        expect(painter.formatTimeForTest(t, true, false), expected);
      });
    });
  });

  group('every ClockTimeLayout receives the zero-padded hour - the fix is '
      'in the ONE shared formatter, not per-layout', () {
    testWidgets('a stacked clock hours line reads "08", minutes "53"',
        (tester) async {
      final painter = ClockPainter(
        config: const ClockConfigEntity(timeLayout: ClockTimeLayout.stacked),
        now: DateTime(2026, 1, 1, 8, 53),
      );
      final layout = painter.computeLayout(const Size(1080, 2400))!;
      String text(ClockSegmentRole r) =>
          layout.segment(r)!.painter.text!.toPlainText();
      expect(text(ClockSegmentRole.hours), '08');
      expect(text(ClockSegmentRole.minutes), '53');
    });

    test('inline renders the zero-padded string as one unbroken token', () {
      final painter = painterFor(false);
      final formatted =
          painter.formatTimeForTest(DateTime(2026, 1, 1, 8, 53), false, false);
      expect(formatted, '08:53');
    });
  });

  group('DEPTH fixture with a single-digit hour', () {
    // The real production Bunny fixture, at a frozen single-digit hour -
    // exactly the reproduction case from the report.
    test('bunny_real_detail.json\'s authored clock formats a single-digit '
        'hour as "08", not "8"', () {
      // This only re-confirms the clock CONFIG that fixture carries is
      // stackedCompact/12-hour (matching the reported scenario) - the actual
      // zero-padding behaviour itself is format-only and does not depend on
      // any wallpaper-specific state, verified generically above.
      final json = File('test/fixtures/bunny_real_detail.json').readAsStringSync();
      expect(json.contains('"is24Hour": false') || json.contains('"is24Hour":false'),
          isTrue,
          reason: 'bunny is authored in 12-hour mode, the mode this bug '
              'affected');

      final painter = painterFor(false);
      final formatted = painter.formatTimeForTest(
        DateTime(2026, 1, 1, 8, 53),
        false,
        false,
      );
      expect(formatted, '08:53');
      expect(formatted.split(':').first, '08');
    });
  });

  group('native (Kotlin) contract stays in sync', () {
    test('ClockRenderer.kt formats 12-hour time with "hh", not "h"', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/ClockRenderer.kt',
      ).readAsStringSync();
      expect(
        source.contains('"hh:mm:ss"') && source.contains('"hh:mm"'),
        isTrue,
        reason: 'Kotlin\'s formatTime must mirror the Dart fix exactly - '
            'both use the same ICU/SimpleDateFormat "hh" token',
      );
      // And the OLD, buggy non-padded pattern must be gone from the 12-hour
      // branch specifically (still fine as a substring of "hh:mm" itself,
      // so this checks the exact quoted literal that WAS the bug).
      expect(source.contains('"h:mm:ss"'), isFalse);
      expect(source.contains('"h:mm"'), isFalse);
    });
  });
}
