import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/remote_clock_config_mapper.dart';
import 'package:creativebackground/features/clock/domain/clock_render_spec.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_painter.dart';
import 'package:creativebackground/features/explore/data/models/wallpaper_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dashboard ↔ mobile clock parity (FLUTTER_RENDERING_GUIDE.md §1, §3).
///
/// Numbers are checked on the real painter's resolved layout, not on source
/// text. The Kotlin twin (`ClockSpec.kt`) has no JVM test harness in this
/// project, so its constants are pinned to the Dart ones textually at the end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phone = Size(1080, 2400); // the dashboard's 9:20 reference phone
  final at0830 = DateTime(2026, 9, 27, 8, 30);
  final at2030 = DateTime(2026, 9, 27, 20, 30);

  ClockLayout layoutOf(ClockConfigEntity c, {DateTime? now, bool device24 = false}) =>
      ClockPainter(config: c, now: now ?? at0830, deviceIs24Hour: device24)
          .computeLayout(phone)!;

  group('1 · size = W * 0.14 * scale * (sizePx / 65)', () {
    test('uses the viewport width, scale and sizePx together', () {
      const c = ClockConfigEntity(scale: 1.3, sizePx: 87);
      expect(ClockRenderSpec.clockSize(1080, c), closeTo(1080 * 0.14 * 1.3 * 87 / 65, 1e-9));
      expect(layoutOf(c).size, closeTo(1080 * 0.14 * 1.3 * 87 / 65, 1e-9));
    });

    test('a smaller preview box scales every size by the same ratio', () {
      const c = ClockConfigEntity(sizePx: 87);
      final full = ClockPainter(config: c, now: at0830).computeLayout(phone)!;
      final card = ClockPainter(config: c, now: at0830).computeLayout(const Size(108, 240))!;
      expect(card.size / full.size, closeTo(0.1, 1e-9));
    });
  });

  group('2-4 · row gap between one-em line boxes', () {
    double gapOf(ClockTimeLayout l, {double lineSpacing = 1}) {
      final layout = layoutOf(ClockConfigEntity(timeLayout: l, lineSpacing: lineSpacing, showDate: false));
      return layout.lineRects[1].top - layout.lineRects[0].bottom;
    }

    test('stacked: 0.08 * size * lineSpacing', () {
      final s = layoutOf(const ClockConfigEntity()).size;
      expect(gapOf(ClockTimeLayout.stacked), closeTo(0.08 * s, 1e-6));
      expect(gapOf(ClockTimeLayout.stacked, lineSpacing: 1.5), closeTo(0.12 * s, 1e-6));
    });
    test('stackedCompact: 0.02 * size * lineSpacing', () {
      final s = layoutOf(const ClockConfigEntity()).size;
      expect(gapOf(ClockTimeLayout.stackedCompact), closeTo(0.02 * s, 1e-6));
    });
    test('offsetStack: 0.08 gap and minutes shifted by minuteOffsetX * size', () {
      const c = ClockConfigEntity(timeLayout: ClockTimeLayout.offsetStack, minuteOffsetX: 0.25, showDate: false);
      final l = layoutOf(c);
      expect(l.lineRects[1].top - l.lineRects[0].bottom, closeTo(0.08 * l.size, 1e-6));
      final hoursCenter = l.lineRects[0].center.dx;
      final minutesCenter = l.lineRects[1].center.dx;
      expect(minutesCenter - hoursCenter, closeTo(0.25 * l.size, 1e-6));
    });
    test('verticalPoster: rows touching, gap 0', () {
      expect(gapOf(ClockTimeLayout.verticalPoster), closeTo(0, 1e-9));
    });
    test('each time line box is exactly one em (size) tall', () {
      final l = layoutOf(const ClockConfigEntity(timeLayout: ClockTimeLayout.stacked));
      for (final r in l.lineRects) {
        expect(r.height, closeTo(l.size, 1e-9));
      }
    });
    test('stacked layouts draw no colon; inline does', () {
      expect(layoutOf(const ClockConfigEntity(timeLayout: ClockTimeLayout.stacked)).segment(ClockSegmentRole.colon), isNull);
      expect(layoutOf(const ClockConfigEntity()).segment(ClockSegmentRole.colon), isNotNull);
    });
  });

  group('5 · AM/PM', () {
    test('12h + showAmPm: drawn after the minutes at 0.3 * size, 0.08 * size gap', () {
      final l = layoutOf(const ClockConfigEntity(showAmPm: true));
      final amPm = l.segment(ClockSegmentRole.amPm)!;
      final minutes = l.segment(ClockSegmentRole.minutes)!;
      expect(amPm.painter.text!.toPlainText(), 'AM');
      expect((amPm.painter.text as TextSpan).style!.fontSize, closeTo(0.3 * l.size, 1e-9));
      expect(amPm.rect.left - minutes.rect.right, closeTo(0.08 * l.size, 1e-6));
      expect(amPm.baselineY, minutes.baselineY, reason: 'shares the minutes baseline');
    });
    test('PM in the afternoon', () {
      final l = layoutOf(const ClockConfigEntity(showAmPm: true), now: at2030);
      expect(l.segment(ClockSegmentRole.amPm)!.painter.text!.toPlainText(), 'PM');
    });
    test('12h + showAmPm false: absent', () {
      expect(layoutOf(const ClockConfigEntity(showAmPm: false)).segment(ClockSegmentRole.amPm), isNull);
    });
    test('24h: absent even when authored on', () {
      expect(layoutOf(const ClockConfigEntity(showAmPm: true, is24Hour: true)).segment(ClockSegmentRole.amPm), isNull);
    });
    test('a stacked clock carries AM/PM on the minutes line', () {
      final l = layoutOf(const ClockConfigEntity(showAmPm: true, timeLayout: ClockTimeLayout.stacked));
      expect(l.segment(ClockSegmentRole.amPm)!.baselineY, l.segment(ClockSegmentRole.minutes)!.baselineY);
    });
    test('split colour mode keeps AM/PM, in the minutes colour', () {
      final l = layoutOf(const ClockConfigEntity(showAmPm: true, colorMode: ClockColorMode.split));
      expect(l.segment(ClockSegmentRole.amPm), isNotNull);
    });
  });

  group('6 · hourFormat precedence', () {
    String hours(ClockConfigEntity c, {bool device24 = false}) =>
        layoutOf(c, now: at2030, device24: device24).segment(ClockSegmentRole.hours)!.painter.text!.toPlainText();

    test('"12" forces 12 hour, over is24Hour', () {
      expect(hours(const ClockConfigEntity(hourFormat: ClockHourFormat.h12, is24Hour: true)), '08');
    });
    test('"24" forces 24 hour', () {
      expect(hours(const ClockConfigEntity(hourFormat: ClockHourFormat.h24)), '20');
    });
    test('"auto" follows the phone', () {
      expect(hours(const ClockConfigEntity(hourFormat: ClockHourFormat.auto), device24: true), '20');
      expect(hours(const ClockConfigEntity(hourFormat: ClockHourFormat.auto)), '08');
    });
    test('no hourFormat (depth clock) uses is24Hour', () {
      expect(hours(const ClockConfigEntity(is24Hour: true)), '20');
    });
    test('the mapper reads "12" / "24" / "auto"', () {
      expect(RemoteClockConfigMapper.fromJson({'hourFormat': '12'})!.hourFormat, ClockHourFormat.h12);
      expect(RemoteClockConfigMapper.fromJson({'hourFormat': '24'})!.hourFormat, ClockHourFormat.h24);
      expect(RemoteClockConfigMapper.fromJson({'hourFormat': 'auto'})!.hourFormat, ClockHourFormat.auto);
      expect(RemoteClockConfigMapper.fromJson({})!.hourFormat, isNull);
    });
  });

  group('7 · the date the clock carries', () {
    test('font size 0.2 * size * dateScale, directly below the time', () {
      final l = layoutOf(const ClockConfigEntity(dateScale: 1.5));
      final style = (l.datePainter!.text as TextSpan).style!;
      expect(style.fontSize, closeTo(0.2 * l.size * 1.5, 1e-9));
      expect(style.letterSpacing, closeTo(0.06 * 0.2 * l.size * 1.5, 1e-9));
      expect(l.dateRect!.top, closeTo(l.timeRect.bottom, 1e-9));
    });
    test('"above" puts it directly above the time', () {
      final l = layoutOf(const ClockConfigEntity(datePosition: ClockDatePosition.above));
      expect(l.dateRect!.bottom, closeTo(l.timeRect.top, 1e-9));
    });
    test('drawn in the clock face and weight', () {
      final l = layoutOf(const ClockConfigEntity(remoteStyle: 'poster'));
      final style = (l.datePainter!.text as TextSpan).style!;
      expect(style.fontFamily, 'ArchivoBlack');
      expect(style.fontWeight, FontWeight.w900);
    });

    test('disabled draws no date', () {
      expect(layoutOf(const ClockConfigEntity(showDate: false)).datePainter, isNull);
    });
    test('format is weekday, month and day', () {
      expect(layoutOf(const ClockConfigEntity()).datePainter!.text!.toPlainText(), 'Sunday, September 27');
    });
  });

  group('8 · position: the centre of the whole piece', () {
    test('customX/customY win over position', () {
      final l = layoutOf(const ClockConfigEntity(position: ClockPosition.top, customX: 0.396, customY: 0.475));
      expect(l.center.dx, closeTo(0.396 * phone.width, 1e-9));
      expect(l.center.dy, closeTo(0.475 * phone.height, 1e-9));
      expect(l.pieceRect.center.dx, closeTo(l.center.dx, 1e-6));
      expect(l.pieceRect.center.dy, closeTo(l.center.dy, 1e-6));
    });
    test('presets sit at 14% / 50% / 78% of the height, centred', () {
      for (final (p, y) in [(ClockPosition.top, 0.14), (ClockPosition.center, 0.5), (ClockPosition.bottom, 0.78)]) {
        final l = layoutOf(ClockConfigEntity(position: p));
        expect(l.center.dy, closeTo(y * phone.height, 1e-9), reason: '$p');
        expect(l.center.dx, closeTo(phone.width / 2, 1e-9));
      }
    });
  });

  group('9-11 · colour modes, gradient, stroke', () {
    test('split / gradient / stroke fields are parsed, not dropped', () {
      final c = RemoteClockConfigMapper.fromJson({
        'colorMode': 'gradient',
        'gradientFrom': '#FF0000FF',
        'gradientTo': '#0000FF80',
        'gradientAngleDeg': 90,
        'fillOpacity': 0.4,
        'showStroke': true,
        'strokeColor': '#00FF00FF',
        'strokeOrder': 'front',
        'strokeWidth': 4,
        'hoursFont': 'Anton',
        'minutesFont': 'Oswald',
        'fadeAmount': 0.3,
        'fadeDirection': 'both',
        'blur': 2,
      })!;
      expect(c.colorMode, ClockColorMode.gradient);
      expect(c.gradientFrom, 0xFFFF0000);
      expect(c.gradientTo, 0x800000FF, reason: 'CSS alpha-last byte order');
      expect(c.gradientAngleDeg, 90);
      expect(c.fillOpacity, 0.4);
      expect(c.strokeColor, 0xFF00FF00);
      expect(c.strokeOrder, ClockStrokeOrder.front);
      expect(c.hoursFont, 'Anton');
      expect(c.minutesFont, 'Oswald');
      expect(c.fadeAmount, 0.3);
      expect(c.fadeDirection, ClockFadeDirection.both);
      expect(c.blur, 2);
    });
    test('"auto" colour mode falls back to single (draws `color`)', () {
      expect(RemoteClockConfigMapper.fromJson({'colorMode': 'auto'})!.colorMode, ClockColorMode.single);
    });
    test('gradient uses the CSS angle convention across the whole block', () {
      final down = ClockRenderSpec.gradientLine(180, 100, 50);
      expect(down.y0, lessThan(down.y1));
      expect(down.x0, closeTo(down.x1, 1e-9));
      final right = ClockRenderSpec.gradientLine(90, 100, 50);
      expect(right.x0, closeTo(0, 1e-9));
      expect(right.x1, closeTo(100, 1e-9));
      final up = ClockRenderSpec.gradientLine(0, 100, 50);
      expect(up.y0, greaterThan(up.y1));
    });
    test('stroke width is strokeWidth * size / 65', () {
      const c = ClockConfigEntity(strokeWidth: 4);
      final s = ClockRenderSpec.clockSize(1080, c);
      expect(ClockRenderSpec.strokeWidth(c, s), closeTo(4 * s / 65, 1e-9));
    });
    test('per-half fonts replace the family for that half only', () {
      const c = ClockConfigEntity(remoteStyle: 'poster', hoursFont: 'Anton');
      expect(ClockRenderSpec.typeface(c, half: ClockHalf.hours).family, 'Anton');
      expect(ClockRenderSpec.typeface(c, half: ClockHalf.minutes).family, 'ArchivoBlack');
    });
    test('style table: poster is ArchivoBlack 900, -0.03 em', () {
      final t = ClockRenderSpec.typeface(const ClockConfigEntity(remoteStyle: 'poster', remoteFont: 'Inter', weight: 400));
      expect((t.family, t.weight, t.letterSpacingEm), ('ArchivoBlack', 900, -0.03));
    });
    test('fade: bottom ramps to 0 at the bottom edge', () {
      final st = ClockRenderSpec.fadeStops(ClockFadeDirection.bottom, 0.3);
      expect(st.first.alpha, 1);
      expect(st[1].offset, closeTo(0.7, 1e-9));
      expect(st.last.alpha, 0);
    });
  });

  group('12 · null / disabled clock draws nothing', () {
    test('an absent clock object parses to null', () {
      expect(RemoteClockConfigMapper.fromJson(null), isNull);
    });
    test('a disabled clock has no layout', () {
      expect(ClockPainter(config: const ClockConfigEntity(enabled: false), now: at0830).computeLayout(phone), isNull);
    });
  });

  group('19 · a legacy clock missing every new field still renders', () {
    test('documented defaults, AM/PM on', () {
      final c = RemoteClockConfigMapper.fromJson({'enabled': true, 'style': 'thin'})!;
      expect(c.sizePx, 65);
      expect(c.scale, 1);
      expect(c.showAmPm, isTrue);
      expect(c.fillOpacity, 1);
      expect(c.strokeOrder, ClockStrokeOrder.behind);
      expect(c.hourFormat, isNull);
      expect(ClockRenderSpec.typeface(c).weight, 200, reason: 'legacy thin');
      expect(layoutOf(c).segment(ClockSegmentRole.hours), isNotNull);
    });
  });

  group('15 · the exact production wallpaper from the comparison photos', () {
    late ClockConfigEntity clock;
    setUpAll(() {
      final json = jsonDecode(File('test/fixtures/bulbs_studio_detail.json').readAsStringSync()) as Map<String, dynamic>;
      final entity = WallpaperModel.fromApiDetail((json['data'] ?? json) as Map<String, dynamic>).toEntity();
      clock = entity.design!.clock!;
    });

    test('every authored field survives to the entity', () {
      expect(clock.remoteStyle, 'poster');
      expect(clock.sizePx, 87);
      expect(clock.scale, 1);
      expect(clock.customX, 0.396);
      expect(clock.customY, 0.475);
      expect(clock.colorMode, ClockColorMode.split);
      expect(clock.hoursColor, 0xFFE0A33C);
      expect(clock.minutesColor, 0xFF34373C);
      expect(clock.showAmPm, isTrue);
      expect(clock.hourFormat, ClockHourFormat.auto);
      expect(clock.showDate, isTrue);
      expect(clock.dateColor, 0xCCFFFFFF);
      expect(clock.showShadow, isTrue);
      expect(clock.shadowStrength, 0.4);
    });

    void report(String label, ClockLayout l) {
      final h = l.segment(ClockSegmentRole.hours)!;
      final m = l.segment(ClockSegmentRole.minutes)!;
      final a = l.segment(ClockSegmentRole.amPm);
      debugPrint('[PARITY $label] viewport=${phone.width}x${phone.height} '
          'size=${l.size.toStringAsFixed(2)} center=(${l.center.dx.toStringAsFixed(1)},${l.center.dy.toStringAsFixed(1)}) '
          'hours=${h.rect} minutes=${m.rect} lines=${l.lineRects} '
          'amPm=${a?.rect} amPmFont=${a == null ? '-' : (a.painter.text as TextSpan).style!.fontSize!.toStringAsFixed(2)} '
          'amPmGap=${a == null ? '-' : (a.rect.left - m.rect.right).toStringAsFixed(2)} '
          'dateFont=${((l.datePainter!.text as TextSpan).style!.fontSize!).toStringAsFixed(2)} date=${l.dateRect} piece=${l.pieceRect}');
    }

    test('as served (inline): size, AM/PM, date and centre follow the contract', () {
      final l = layoutOf(clock);
      report('inline', l);
      final s = 1080 * 0.14 * 1 * 87 / 65;
      expect(l.size, closeTo(s, 1e-9));
      expect(l.segment(ClockSegmentRole.amPm), isNotNull, reason: 'AM/PM was missing on the phone');
      expect((l.segment(ClockSegmentRole.amPm)!.painter.text as TextSpan).style!.fontSize, closeTo(0.3 * s, 1e-9));
      expect(((l.datePainter!.text as TextSpan).style!.fontSize)!, closeTo(0.2 * s, 1e-9),
          reason: 'the date was drawn far larger on the phone');
      expect(l.center, Offset(0.396 * 1080, 0.475 * 2400));
    });

    test('as photographed (stacked): 0.08 * size between the em rows, AM/PM on the minutes line', () {
      final l = layoutOf(clock.copyWith(timeLayout: ClockTimeLayout.stacked));
      report('stacked', l);
      expect(l.lineRects[1].top - l.lineRects[0].bottom, closeTo(0.08 * l.size, 1e-6));
      expect(l.segment(ClockSegmentRole.amPm)!.baselineY, l.segment(ClockSegmentRole.minutes)!.baselineY);
    });
  });

  group('Dart ↔ Kotlin: ClockSpec.kt carries the same formulas', () {
    late String kt;
    setUpAll(() => kt = File('android/app/src/main/kotlin/com/backgrounds/trend4k/ClockSpec.kt').readAsStringSync());

    for (final expr in [
      'viewportWidth * 0.14f * c.scale * (c.sizePx / 65f)',
      '"stacked" -> 0.08f * size * lineSpacing',
      '"stackedCompact" -> 0.02f * size * lineSpacing',
      '"offsetStack" -> 0.08f * size * lineSpacing',
      'c.minuteOffsetX * size',
      'fun amPmFontSize(size: Float): Float = 0.3f * size',
      'fun amPmGap(size: Float): Float = 0.08f * size',
      'AM_PM_LETTER_SPACING_EM = 0.04f',
      'fun dateFontSize(size: Float, dateScale: Float): Float = 0.2f * size * dateScale',
      'DATE_LETTER_SPACING_EM = 0.06f',
      'c.strokeWidth * (size / 65f)',
      'fun shadowOffsetY(size: Float): Float = 0.04f * size',
      'fun shadowBlur(size: Float): Float = 0.05f * size',
      'fun glowInnerBlur(size: Float): Float = 0.18f * size',
      'fun glowOuterBlur(size: Float): Float = 0.30f * size',
      'c.blur * (size / 65f)',
      '"top" -> 0.14f',
      '"bottom" -> 0.78f',
      '"poster" -> Face(ARCHIVO, 900, -0.03f)',
      '"minimal" -> Face(own, 300, 0.12f)',
      '"elegant" -> Face(SERIF, w, 0f, italic = true)',
      '"monument" -> Face(OSWALD, 700, -0.03f)',
      '"auto" -> deviceIs24Hour',
    ]) {
      test(expr, () => expect(kt.contains(expr), isTrue, reason: 'ClockSpec.kt drifted from ClockRenderSpec'));
    }
  });
}
