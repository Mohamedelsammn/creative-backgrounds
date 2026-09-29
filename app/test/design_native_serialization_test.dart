import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/clock_config_model.dart';
import 'package:creativebackground/features/clock/data/models/remote_clock_config_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 10: the SAME canonical configuration must reach every renderer.
///
/// Details reads [ClockConfigEntity] directly; the applied wallpaper gets it
/// as JSON via `ClockConfigModel.fromEntity(...).toJson()`, which
/// `ClockConfig.kt` then parses. A field that survives the mapper but is
/// dropped in that serialization would make Details and the applied wallpaper
/// disagree - which is the exact class of bug this pass exists to remove.
void main() {
  /// The keys `ClockConfig.kt` reads, with the defaults it falls back to.
  /// Mirrors `ClockConfig.fromJson` field for field.
  const nativeKeys = <String>[
    'sizePx',
    'stretchY',
    'dateScale',
    'fontWeightPreset',
    'horizontalScale',
    'timeLayout',
    'showColon',
    'lineSpacing',
    'minuteOffsetX',
    'colorMode',
    'hoursColor',
    'minutesColor',
    'colonColor',
    'colonColorCustom',
    'strokeWidth',
  ];

  ClockConfigEntity bunny() {
    final raw =
        File('test/fixtures/bunny_clock_config.json').readAsStringSync();
    return RemoteClockConfigMapper.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    )!;
  }

  Map<String, dynamic> nativeJson(ClockConfigEntity e) =>
      ClockConfigModel.fromEntity(e).toJson();

  group('the native payload carries every field the renderers support', () {
    test('every key ClockConfig.kt reads is present', () {
      final json = nativeJson(bunny());
      for (final key in nativeKeys) {
        expect(
          json.containsKey(key),
          isTrue,
          reason: '$key is read by ClockConfig.kt but never serialized',
        );
      }
    });

    test('Bunny reaches native with its authored values intact', () {
      final json = nativeJson(bunny());
      // These are exactly the properties that were lost before this pass.
      expect(json['sizePx'], 208);
      expect(json['timeLayout'], 'stackedCompact');
      expect(json['colorMode'], 'split');
      expect(json['minutesColor'], 0xFFE65100);
      expect(json['font'], 'oswald');
      expect(json['style'], 'monument');
    });

    test('the wire strings match the Kotlin switch vocabulary exactly', () {
      // `ClockRenderer.kt` compares `config.timeLayout == "inline"` and
      // `config.colorMode == "split"` as raw strings, and looks up fonts by
      // "oswald" / "archivoBlack" / "anton". A renamed enum would silently
      // stop matching, so the serialized spelling is pinned here.
      for (final entry in {
        ClockTimeLayout.inline: 'inline',
        ClockTimeLayout.stacked: 'stacked',
        ClockTimeLayout.stackedCompact: 'stackedCompact',
        ClockTimeLayout.offsetStack: 'offsetStack',
        ClockTimeLayout.verticalPoster: 'verticalPoster',
      }.entries) {
        expect(
          nativeJson(ClockConfigEntity(timeLayout: entry.key))['timeLayout'],
          entry.value,
        );
      }

      for (final entry in {
        ClockFont.inter: 'inter',
        ClockFont.serif: 'serif',
        ClockFont.mono: 'mono',
        ClockFont.oswald: 'oswald',
        ClockFont.archivoBlack: 'archivoBlack',
        ClockFont.anton: 'anton',
      }.entries) {
        expect(nativeJson(ClockConfigEntity(font: entry.key))['font'],
            entry.value);
      }

      for (final entry in {
        ClockColorMode.single: 'single',
        ClockColorMode.split: 'split',
      }.entries) {
        expect(
          nativeJson(ClockConfigEntity(colorMode: entry.key))['colorMode'],
          entry.value,
        );
      }

      for (final entry in {
        ClockColonColor.hours: 'hours',
        ClockColonColor.minutes: 'minutes',
        ClockColonColor.custom: 'custom',
      }.entries) {
        expect(
          nativeJson(ClockConfigEntity(colonColor: entry.key))['colonColor'],
          entry.value,
        );
      }
    });

    test('every ClockStyle serializes to the id ClockStylePreset.kt knows', () {
      const known = {
        ClockStyle.modern: 'modern',
        ClockStyle.minimal: 'minimal',
        ClockStyle.elegant: 'elegant',
        ClockStyle.digital: 'digital',
        ClockStyle.condensed: 'condensed',
        ClockStyle.poster: 'poster',
        ClockStyle.outline: 'outline',
        ClockStyle.split: 'split',
        ClockStyle.futuristic: 'futuristic',
        ClockStyle.editorial: 'editorial',
        ClockStyle.monument: 'monument',
        ClockStyle.stencil: 'stencil',
        ClockStyle.soft: 'soft',
      };
      expect(known.length, ClockStyle.values.length);
      known.forEach((style, id) {
        expect(nativeJson(ClockConfigEntity(style: style))['style'], id);
      });
    });
  });

  group('entity -> native -> entity is lossless', () {
    test('a full round-trip preserves every field', () {
      final original = bunny();
      final restored = ClockConfigModel.fromJson(
        nativeJson(original),
      ).toEntity();
      // Equatable compares every field.
      expect(restored, original);
    });

    test('the Details config and the applied config are the same object', () {
      // Details renders `wallpaper.remoteClockConfig`; apply serializes the
      // same entity. This asserts there is no divergent transformation in
      // between - the whole point of one canonical model.
      final forDetails = bunny();
      final forApply = ClockConfigModel.fromEntity(forDetails).toEntity();
      expect(forApply, forDetails);
    });
  });

  group('colour byte order survives to native', () {
    test('a CSS #RRGGBBAA colour becomes an ARGB int, not a swapped one', () {
      final c = RemoteClockConfigMapper.fromJson({
        'color': '#E65100FF',
        'colorMode': 'split',
        'minutesColor': '#E65100',
      })!;
      // 0xFFE65100 = opaque orange. A byte-order bug would give 0x5100FFE6.
      expect(c.color, 0xFFE65100);
      expect(nativeJson(c)['color'], 0xFFE65100);
      expect(nativeJson(c)['minutesColor'], 0xFFE65100);
    });

    test('a half-transparent authored colour keeps its alpha', () {
      final c = RemoteClockConfigMapper.fromJson({'color': '#FFFFFF80'})!;
      expect((c.color >> 24) & 0xFF, 0x80);
    });
  });
}
