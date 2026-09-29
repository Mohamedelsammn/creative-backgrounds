import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/remote_clock_config_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for [RemoteClockConfigMapper] against the CURRENT backend
/// clock schema (see `docs/DESIGN_RENDERING_CONTRACT.md`).
///
/// The regression these guard against: the mapper read 15 of 48 authored
/// fields and dropped the other 33, so a dashboard-authored clock rendered at
/// the wrong size, layout, font, style and colour. Every field asserted here
/// is one the existing rendering pipeline (entity -> ClockPainter ->
/// ClockConfigModel -> ClockConfig.kt -> ClockRenderer.kt) already supports
/// end to end, so a value that survives this mapper reaches both renderers.
void main() {
  group('Bunny regression - real authored config from the production API', () {
    // The real `clockConfig` for `bunny-25m3g7`, captured verbatim from
    // GET /api/v1/public/wallpapers/bunny-25m3g7. Nothing about this test is
    // Bunny-specific in the mapper itself - this is simply the wallpaper whose
    // rendering was reported as wrong, used as a real-world fixture.
    late ClockConfigEntity clock;

    setUpAll(() {
      final raw = File('test/fixtures/bunny_clock_config.json').readAsStringSync();
      final parsed = RemoteClockConfigMapper.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(parsed, isNotNull, reason: 'the fixture is a valid clock object');
      clock = parsed!;
    });

    test('timeLayout is stackedCompact, not inline', () {
      expect(clock.timeLayout, ClockTimeLayout.stackedCompact);
    });

    test('colorMode is split, so hours and minutes colour independently', () {
      expect(clock.colorMode, ClockColorMode.split);
    });

    test('minutesColor is the authored orange #E65100, not white', () {
      expect(clock.minutesColor, 0xFFE65100);
    });

    test('hoursColor is unauthored (null), so it falls back to `color`', () {
      expect(clock.hoursColor, isNull);
      expect(clock.color, 0xFFFFFFFF);
    });

    test('sizePx is the authored 208, not 76 recomputed from scale', () {
      expect(clock.sizePx, 208);
    });

    test('font is Oswald, not Inter', () {
      expect(clock.font, ClockFont.oswald);
      expect(clock.remoteFont, 'Oswald');
    });

    test('style is monument, not modern', () {
      expect(clock.style, ClockStyle.monument);
      expect(clock.remoteStyle, 'monument');
    });

    test('the authored position survives exactly', () {
      expect(clock.customX, closeTo(0.348, 1e-9));
      expect(clock.customY, closeTo(0.274, 1e-9));
      expect(clock.hasCustomPosition, isTrue);
    });

    test('the remaining authored values are carried too', () {
      expect(clock.enabled, isTrue);
      expect(clock.weight, 700);
      expect(clock.opacity, 1.0);
      expect(clock.depth, 0.45);
      expect(clock.rotation, 0);
      expect(clock.showColon, isTrue);
      expect(clock.showStroke, isFalse);
      expect(clock.showGlow, isFalse);
      expect(clock.showSeconds, isFalse);
      expect(clock.strokeWidth, 2);
      expect(clock.stretchY, 1);
      expect(clock.horizontalScale, 1);
      expect(clock.lineSpacing, 1);
      expect(clock.minuteOffsetX, 0);
      expect(clock.dateScale, 1);
      expect(clock.fontWeightPreset, ClockWeight.regular);
      expect(clock.colonColor, ClockColonColor.hours);
      expect(clock.colonColorCustom, isNull);
      expect(clock.schemaVersion, 1);
    });

    test('the authored shadow is honoured', () {
      expect(clock.showShadow, isTrue);
      expect(clock.shadowStrength, closeTo(0.4, 1e-9));
    });

    test('the date is authored OFF and stays off', () {
      expect(clock.showDate, isFalse);
    });
  });

  group('sizePx precedence', () {
    ClockConfigEntity parse(Map<String, dynamic> json) =>
        RemoteClockConfigMapper.fromJson(json)!;

    test('an explicit sizePx is authoritative and ignores scale', () {
      // 208 with scale 1.3 must stay 208, never 208*1.3 and never 76*1.3.
      final c = parse({'sizePx': 208, 'scale': 1.3});
      expect(c.sizePx, 208);
    });

    test('a legacy config with no sizePx keeps 65 and scale separate', () {
      // FLUTTER_RENDERING_GUIDE §3.1: size = W * 0.14 * scale * sizePx / 65,
      // so folding scale into sizePx would apply it twice.
      final c = parse({'scale': 1.5});
      expect(c.sizePx, 65);
      expect(c.scale, 1.5);
    });

    test('a legacy config with neither falls back to 65 / scale 1', () {
      final c = parse(<String, dynamic>{});
      expect(c.sizePx, 65);
      expect(c.scale, 1.0);
    });

    test('an authored size above the old 120 ceiling is NOT clamped to it', () {
      // The old ceiling silently shrank every large authored clock.
      final c = parse({'sizePx': 300});
      expect(c.sizePx, 300);
      expect(c.sizePx, greaterThan(120));
    });

    test('a corrupt sizePx never produces an invisible clock', () {
      // Out of range clamps to the contract's 24 minimum; unparseable is 65.
      for (final bad in <Object?>[0, -50]) {
        expect(parse({'sizePx': bad}).sizePx, 24, reason: 'sizePx: $bad');
      }
      for (final bad in <Object?>['big', null]) {
        expect(parse({'sizePx': bad}).sizePx, 65, reason: 'sizePx: $bad');
      }
    });

    test('an absurd sizePx is bounded rather than allowed to allocate', () {
      final c = parse({'sizePx': 1e9});
      expect(c.sizePx, RemoteClockConfigMapper.maxSizePx);
    });
  });

  group('font mapping', () {
    ClockFont fontOf(String? name) =>
        RemoteClockConfigMapper.fromJson({'font': name})!.font;

    test('the bundled display faces are reachable', () {
      expect(fontOf('Oswald'), ClockFont.oswald);
      expect(fontOf('ArchivoBlack'), ClockFont.archivoBlack);
      expect(fontOf('Anton'), ClockFont.anton);
    });

    test('spelling variants still resolve', () {
      expect(fontOf('archivo black'), ClockFont.archivoBlack);
      expect(fontOf('Archivo-Black'), ClockFont.archivoBlack);
      expect(fontOf('OSWALD'), ClockFont.oswald);
    });

    test('serif and mono families keep matching by keyword', () {
      expect(fontOf('PlayfairDisplay'), ClockFont.serif);
      expect(fontOf('JetBrainsMono'), ClockFont.mono);
    });

    test('an unknown family falls back to Inter but keeps the raw name', () {
      final c = RemoteClockConfigMapper.fromJson({'font': 'SomeFutureFace'})!;
      expect(c.font, ClockFont.inter);
      expect(c.remoteFont, 'SomeFutureFace');
    });

    test('an absent font is Inter', () {
      expect(fontOf(null), ClockFont.inter);
    });
  });

  group('style mapping', () {
    ClockStyle styleOf(String? id) =>
        RemoteClockConfigMapper.fromJson({'style': id})!.style;

    test('every renderer style is reachable by its own id', () {
      const expected = {
        'modern': ClockStyle.modern,
        'minimal': ClockStyle.minimal,
        'elegant': ClockStyle.elegant,
        'digital': ClockStyle.digital,
        'condensed': ClockStyle.condensed,
        'poster': ClockStyle.poster,
        'outline': ClockStyle.outline,
        'split': ClockStyle.split,
        'futuristic': ClockStyle.futuristic,
        'editorial': ClockStyle.editorial,
        'monument': ClockStyle.monument,
        'stencil': ClockStyle.stencil,
        'soft': ClockStyle.soft,
      };
      // Guards against a new ClockStyle being added without a wire id.
      expect(expected.length, ClockStyle.values.length);
      expected.forEach((id, style) => expect(styleOf(id), style, reason: id));
    });

    test('legacy aliases still resolve as before', () {
      expect(styleOf('thin'), ClockStyle.minimal);
      expect(styleOf('classic'), ClockStyle.elegant);
      expect(styleOf('solid'), ClockStyle.modern);
      expect(styleOf('bold'), ClockStyle.modern);
      expect(styleOf('rounded'), ClockStyle.modern);
      expect(styleOf('outlined'), ClockStyle.modern);
    });

    test('the legacy `outlined` id still implies a stroked glyph', () {
      expect(RemoteClockConfigMapper.fromJson({'style': 'outlined'})!.showStroke,
          isTrue);
    });

    test('an explicit showStroke wins over the style implication', () {
      final c = RemoteClockConfigMapper.fromJson(
        {'style': 'outlined', 'showStroke': false},
      )!;
      expect(c.showStroke, isFalse);
    });

    test('an unknown future style falls back without losing the raw id', () {
      final c = RemoteClockConfigMapper.fromJson({'style': 'hologram'})!;
      expect(c.style, ClockStyle.modern);
      expect(c.remoteStyle, 'hologram');
    });
  });

  group('layout and split-colour vocabulary', () {
    test('every timeLayout value round-trips from the wire', () {
      const expected = {
        'inline': ClockTimeLayout.inline,
        'stacked': ClockTimeLayout.stacked,
        'stackedCompact': ClockTimeLayout.stackedCompact,
        'offsetStack': ClockTimeLayout.offsetStack,
        'verticalPoster': ClockTimeLayout.verticalPoster,
      };
      expect(expected.length, ClockTimeLayout.values.length);
      expected.forEach((wire, value) {
        expect(
          RemoteClockConfigMapper.fromJson({'timeLayout': wire})!.timeLayout,
          value,
          reason: wire,
        );
      });
    });

    test('an unknown layout falls back to inline', () {
      expect(
        RemoteClockConfigMapper.fromJson({'timeLayout': 'spiral'})!.timeLayout,
        ClockTimeLayout.inline,
      );
    });

    test('every colonColor value round-trips', () {
      const expected = {
        'hours': ClockColonColor.hours,
        'minutes': ClockColonColor.minutes,
        'custom': ClockColonColor.custom,
      };
      expect(expected.length, ClockColonColor.values.length);
      expected.forEach((wire, value) {
        expect(
          RemoteClockConfigMapper.fromJson({'colonColor': wire})!.colonColor,
          value,
          reason: wire,
        );
      });
    });

    test('every fontWeightPreset value round-trips', () {
      const expected = {
        'extraLight': ClockWeight.extraLight,
        'light': ClockWeight.light,
        'regular': ClockWeight.regular,
        'medium': ClockWeight.medium,
        'semiBold': ClockWeight.semiBold,
        'bold': ClockWeight.bold,
        'extraBold': ClockWeight.extraBold,
        'black': ClockWeight.black,
      };
      expect(expected.length, ClockWeight.values.length);
      expected.forEach((wire, value) {
        expect(
          RemoteClockConfigMapper.fromJson(
            {'fontWeightPreset': wire},
          )!.fontWeightPreset,
          value,
          reason: wire,
        );
      });
    });

    test('split colours are read in CSS byte order (#RRGGBBAA)', () {
      final c = RemoteClockConfigMapper.fromJson({
        'colorMode': 'split',
        'hoursColor': '#FF0000FF',
        'minutesColor': '#E65100',
        'colonColor': 'custom',
        'colonColorCustom': '#00FF00FF',
      })!;
      expect(c.colorMode, ClockColorMode.split);
      expect(c.hoursColor, 0xFFFF0000);
      expect(c.minutesColor, 0xFFE65100);
      expect(c.colonColorCustom, 0xFF00FF00);
    });
  });

  group('absent sub-objects mean OFF, not ON', () {
    test('no shadow object means no shadow', () {
      expect(RemoteClockConfigMapper.fromJson(<String, dynamic>{})!.showShadow,
          isFalse);
    });

    test('no date object means no date', () {
      expect(
          RemoteClockConfigMapper.fromJson(<String, dynamic>{})!.showDate,
          isFalse);
    });

    test('an authored shadow/date is still honoured', () {
      final c = RemoteClockConfigMapper.fromJson({
        'shadow': {'enabled': true, 'strength': 0.4},
        'date': {'enabled': true, 'position': 'above', 'color': '#FF0000FF'},
      })!;
      expect(c.showShadow, isTrue);
      expect(c.shadowStrength, closeTo(0.4, 1e-9));
      expect(c.showDate, isTrue);
      expect(c.datePosition, ClockDatePosition.above);
      expect(c.dateColor, 0xFFFF0000);
    });
  });

  group('forward and backward compatibility', () {
    test('a null or non-map input is "no authored clock"', () {
      expect(RemoteClockConfigMapper.fromJson(null), isNull);
      expect(RemoteClockConfigMapper.fromJson('nope'), isNull);
      expect(RemoteClockConfigMapper.fromJson(42), isNull);
    });

    test('unknown future fields are ignored, not fatal', () {
      final c = RemoteClockConfigMapper.fromJson({
        'sizePx': 100,
        'someFutureField': {'nested': true},
        'anotherOne': [1, 2, 3],
      });
      expect(c, isNotNull);
      expect(c!.sizePx, 100);
    });

    test('wrong types everywhere fall back instead of throwing', () {
      final c = RemoteClockConfigMapper.fromJson({
        'enabled': 'yes',
        'scale': 'big',
        'weight': [],
        'opacity': {},
        'customX': 'left',
        'color': 12345,
        'shadow': 'none',
        'date': 7,
        'timeLayout': 99,
        'colorMode': true,
      });
      expect(c, isNotNull);
      expect(c!.enabled, isTrue);
      expect(c.weight, 400);
      expect(c.opacity, 1.0);
      expect(c.customX, isNull);
      expect(c.color, 0xFFFFFFFF);
      expect(c.timeLayout, ClockTimeLayout.inline);
      expect(c.colorMode, ClockColorMode.single);
    });

    test('NaN and Infinity do not leak into the renderers', () {
      final c = RemoteClockConfigMapper.fromJson({
        'scale': double.nan,
        'opacity': double.infinity,
        'rotation': double.negativeInfinity,
        'customY': double.nan,
      })!;
      expect(c.scale.isFinite, isTrue);
      expect(c.opacity.isFinite, isTrue);
      expect(c.rotation.isFinite, isTrue);
      expect(c.customY, isNull);
      expect(c.sizePx.isFinite, isTrue);
    });

    test('an out-of-range number is clamped to the documented range', () {
      final c = RemoteClockConfigMapper.fromJson({
        'opacity': 5,
        'weight': 5000,
        'rotation': 720,
        'customX': 1.7,
        'depth': -3,
      })!;
      expect(c.opacity, 1.0);
      expect(c.weight, 900);
      expect(c.rotation, 180);
      expect(c.customX, 1.0);
      expect(c.depth, 0.0);
    });

    test('studio.clock parses through the same reader as clockConfig', () {
      // The two containers share 45 fields; `studio.clock` simply has no
      // `schemaVersion`. Absent must mean generation 1, not a parse failure.
      final c = RemoteClockConfigMapper.fromJson({
        'enabled': true,
        'sizePx': 65,
        'timeLayout': 'inline',
        'style': 'classic',
        'font': 'PlayfairDisplay',
        'hourFormat': 'auto', // studio-only field, not yet modelled
        'separatorBlink': false, // studio-only field, not yet modelled
      })!;
      expect(c.schemaVersion, 1);
      expect(c.sizePx, 65);
      expect(c.style, ClockStyle.elegant);
      expect(c.font, ClockFont.serif);
    });
  });

  group('toJson round-trip', () {
    test('every mapped field survives a parse -> serialize -> parse cycle', () {
      final raw = File('test/fixtures/bunny_clock_config.json').readAsStringSync();
      final first = RemoteClockConfigMapper.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      )!;
      final second =
          RemoteClockConfigMapper.fromJson(RemoteClockConfigMapper.toJson(first))!;

      // Equatable compares every field, so this asserts the whole entity.
      expect(second, first);
    });

    test('a round-trip does not resurrect the derived-size bug', () {
      final first = RemoteClockConfigMapper.fromJson({'sizePx': 208, 'scale': 1.0})!;
      final second =
          RemoteClockConfigMapper.fromJson(RemoteClockConfigMapper.toJson(first))!;
      expect(second.sizePx, 208);
    });
  });

  group('coordinate anchor (Stage 9 evidence)', () {
    // `docs/DEPTH_WALLPAPER_DASHBOARD_CONTRACT.md` §3 documents verbatim:
    //   | `customX` | 0 | 1 | null | normalized clock CENTER X |
    //   | `customY` | 0 | 1 | null | normalized clock CENTER Y |
    // Both renderers already centre-anchor (`ClockPainter._centerX` returns
    // `width * x`; `_positionTop` returns `(height * y) - blockHeight / 2`;
    // `ClockRenderer.kt` mirrors both), so dashboard and mobile agree and NO
    // conversion is applied. These tests pin that down so a future "fix"
    // cannot quietly introduce an offset.
    test('authored coordinates pass through untransformed', () {
      final c = RemoteClockConfigMapper.fromJson({
        'position': 'custom',
        'customX': 0.348,
        'customY': 0.274,
      })!;
      expect(c.customX, closeTo(0.348, 1e-9));
      expect(c.customY, closeTo(0.274, 1e-9));
    });

    test('the entity reports the authored centre as its effective centre', () {
      final c = RemoteClockConfigMapper.fromJson({
        'position': 'custom',
        'customX': 0.2,
        'customY': 0.8,
      })!;
      expect(c.effectiveNormalizedX, closeTo(0.2, 1e-9));
      expect(c.effectiveNormalizedY, closeTo(0.8, 1e-9));
    });

    test('out-of-range coordinates are clamped into 0..1, not wrapped', () {
      final c = RemoteClockConfigMapper.fromJson({
        'position': 'custom',
        'customX': 1.4,
        'customY': -0.3,
      })!;
      expect(c.customX, 1.0);
      expect(c.customY, 0.0);
    });
  });
}
