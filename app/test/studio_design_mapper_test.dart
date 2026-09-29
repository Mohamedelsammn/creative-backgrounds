import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/studio_design_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the `studio` object - the current backend design generation,
/// which was previously not parsed at all (Phase 0 found zero references to
/// `studio` anywhere in `lib/`).
///
/// The fixtures are real production payloads, captured verbatim from
/// GET /api/v1/public/wallpapers?limit=60.
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  StudioDesign? parse(Map<String, dynamic> f) => StudioDesignMapper.fromJson(
        f['studio'],
        legacyClockConfig: f['clockConfig'],
      );

  group('real production payloads', () {
    test('a studio wallpaper with a clock and a batteryRing parses fully', () {
      final design = parse(fixture('studio_battery_ring'))!;

      expect(design.clock, isNotNull);
      expect(design.clock!.enabled, isTrue);
      expect(design.widgets, hasLength(1));

      final ring = design.widgets.single as StudioBatteryRing;
      expect(ring.customX, closeTo(0.8, 1e-9));
      expect(ring.customY, closeTo(0.13, 1e-9));
      expect(ring.scale, closeTo(1.1, 1e-9));
      expect(ring.color, 0xFFFFFFFF);
      expect(ring.showPercentage, isTrue);
      expect(ring.anchor, 'top');
    });

    test('its dateWidget is a separate element from the clock date', () {
      final design = parse(fixture('studio_battery_ring'))!;
      expect(design.dateWidget, isNotNull);
      expect(design.dateWidget!.enabled, isTrue);
      expect(design.dateWidget!.hasCustomPosition, isTrue);
      // The clock's own nested date is independently OFF - the two must not be
      // confused for one another.
      expect(design.clock!.showDate, isFalse);
    });

    test('applyTarget is read from behavior', () {
      final design = parse(fixture('studio_battery_ring'))!;
      expect(design.applyTarget, StudioApplyTarget.ask);
    });

    test(
        'a wallpaper carrying BOTH studio and clockConfig takes the clock from '
        'the legacy field when studio.clock is null', () {
      // This is the real precedence trap: `studio` exists, but its clock is
      // null, and the actual authored clock lives in the legacy top-level
      // `clockConfig`. Treating "has studio" as "ignore clockConfig" would
      // lose the clock entirely.
      final raw = fixture('studio_dual_container');
      expect(raw['studio'], isNotNull);
      expect((raw['studio'] as Map)['clock'], isNull);
      expect(raw['clockConfig'], isNotNull);

      final design = parse(raw)!;
      expect(design.clock, isNotNull);
      expect(design.clock!.enabled, isTrue);
      // Values authored in the legacy container, proving it was actually read.
      expect(design.clock!.timeLayout, ClockTimeLayout.stackedCompact);
      expect(design.clock!.style, ClockStyle.monument);
      expect(design.clock!.sizePx, 183);
    });

    test('that wallpaper still gets its studio scene and preview', () {
      final design = parse(fixture('studio_dual_container'))!;
      expect(design.scene, isNotNull);
      expect(design.scene!.brightness, closeTo(-0.1, 1e-9));
      expect(design.scene!.vignetteAmount, closeTo(0.35, 1e-9));
      expect(design.styledPreviewUrl, isNotNull);
      expect(design.styledPreviewUrl, startsWith('https://'));
    });

    test('a studio wallpaper with no widgets has an empty widget list', () {
      final design = parse(fixture('studio_static_clock'))!;
      expect(design.widgets, isEmpty);
      expect(design.unsupportedWidgetKinds, isEmpty);
    });
  });

  group('clock precedence', () {
    test('studio.clock wins when both are present', () {
      final design = StudioDesignMapper.fromJson(
        {
          'clock': {'enabled': true, 'sizePx': 100},
        },
        legacyClockConfig: {'enabled': true, 'sizePx': 40},
      )!;
      expect(design.clock!.sizePx, 100);
    });

    test('the legacy clockConfig is used when studio.clock is null', () {
      final design = StudioDesignMapper.fromJson(
        {'clock': null, 'scene': null},
        legacyClockConfig: {'enabled': true, 'sizePx': 40},
      )!;
      expect(design.clock!.sizePx, 40);
    });

    test('a legacy wallpaper with no studio still yields a design', () {
      final design = StudioDesignMapper.fromJson(
        null,
        legacyClockConfig: {'enabled': true, 'sizePx': 55},
      )!;
      expect(design.clock!.sizePx, 55);
      expect(design.scene, isNull);
      expect(design.widgets, isEmpty);
      // Nothing was authored about apply behavior, so the safe default applies.
      expect(design.applyTarget, StudioApplyTarget.ask);
    });

    test('a wallpaper with neither container has no design at all', () {
      expect(StudioDesignMapper.fromJson(null), isNull);
      expect(
        StudioDesignMapper.fromJson(null, legacyClockConfig: null),
        isNull,
      );
    });
  });

  group('hasDesign semantics', () {
    test('an enabled clock is a design', () {
      final d = StudioDesignMapper.fromJson(
        null,
        legacyClockConfig: {'enabled': true},
      )!;
      expect(d.hasDesign, isTrue);
    });

    test('a clock authored OFF is not a design', () {
      final d = StudioDesignMapper.fromJson(
        null,
        legacyClockConfig: {'enabled': false},
      )!;
      expect(d.hasDesign, isFalse);
    });

    test('a scene at identity values is not a design', () {
      // Every production wallpaper carries a full scene object; almost all of
      // them are entirely at 0. Treating that as "designed" would mark nearly
      // the whole catalogue as designed.
      final d = StudioDesignMapper.fromJson({
        'scene': {
          'brightness': 0,
          'contrast': 0,
          'saturation': 0,
          'vignette': {'amount': 0, 'softness': 0.5},
          'grain': {'amount': 0, 'size': 1},
          'tint': {'enabled': false, 'color': '#000000FF'},
          'duotone': {'enabled': false},
          'gradientOverlay': {'enabled': false},
        },
      });
      expect(d?.hasDesign ?? false, isFalse);
    });

    test('a scene with a visible effect IS a design', () {
      final d = StudioDesignMapper.fromJson({
        'scene': {'brightness': -0.1},
      })!;
      expect(d.hasDesign, isTrue);
      expect(d.scene!.hasVisibleEffect, isTrue);
    });

    test('an enabled gradient/tint/duotone counts as visible', () {
      for (final key in ['gradientOverlay', 'tint', 'duotone']) {
        final d = StudioDesignMapper.fromJson({
          'scene': {
            key: {'enabled': true},
          },
        })!;
        expect(d.hasDesign, isTrue, reason: key);
      }
    });

    test('a supported widget alone is a design', () {
      final d = StudioDesignMapper.fromJson({
        'widgets': [
          {'kind': 'batteryRing'},
        ],
      })!;
      expect(d.hasDesign, isTrue);
    });

    test('an enabled dateWidget alone is a design', () {
      final d = StudioDesignMapper.fromJson({
        'dateWidget': {'enabled': true},
      })!;
      expect(d.hasDesign, isTrue);
    });

    test('an empty studio object is not a design', () {
      final d = StudioDesignMapper.fromJson(<String, dynamic>{});
      expect(d?.hasDesign ?? false, isFalse);
    });
  });

  group('dynamic vs static classification', () {
    test('an enabled clock is dynamic - it shows the current time', () {
      final d = StudioDesignMapper.fromJson(
        null,
        legacyClockConfig: {'enabled': true},
      )!;
      expect(d.isDynamic, isTrue);
      expect(d.renderMode, DesignRenderMode.dynamic_);
    });

    test('a batteryRing is dynamic - it reflects live battery state', () {
      final d = StudioDesignMapper.fromJson({
        'widgets': [
          {'kind': 'batteryRing'},
        ],
      })!;
      expect(d.isDynamic, isTrue);
      expect(d.renderMode, DesignRenderMode.dynamic_);
    });

    test('a scene-only design is STATIC and can be baked', () {
      final d = StudioDesignMapper.fromJson({
        'scene': {'brightness': -0.2, 'contrast': 0.1},
      })!;
      expect(d.hasDesign, isTrue);
      expect(d.isDynamic, isFalse);
      expect(d.renderMode, DesignRenderMode.static_);
    });

    test('a dateWidget-only design is STATIC', () {
      // A date changes at midnight, not continuously; it does not justify a
      // persistent live wallpaper service.
      final d = StudioDesignMapper.fromJson({
        'dateWidget': {'enabled': true},
      })!;
      expect(d.renderMode, DesignRenderMode.static_);
    });

    test('a disabled clock does not make an otherwise static design dynamic',
        () {
      final d = StudioDesignMapper.fromJson({
        'clock': {'enabled': false},
        'scene': {'brightness': -0.2},
      })!;
      expect(d.renderMode, DesignRenderMode.static_);
    });

    test('no design at all is renderMode none', () {
      final d = StudioDesignMapper.fromJson(<String, dynamic>{});
      expect(d?.renderMode ?? DesignRenderMode.none, DesignRenderMode.none);
    });
  });

  group('applyTarget', () {
    StudioApplyTarget targetOf(Object? value) => StudioDesignMapper.fromJson({
          'behavior': {'applyTarget': value},
        })!
            .applyTarget;

    test('ask is read', () => expect(targetOf('ask'), StudioApplyTarget.ask));

    test('withDesign is read', () {
      expect(targetOf('withDesign'), StudioApplyTarget.withDesign);
    });

    test('wallpaperOnly is read', () {
      expect(targetOf('wallpaperOnly'), StudioApplyTarget.wallpaperOnly);
    });

    test('an unknown mode falls back to ask, never to silently overriding', () {
      expect(targetOf('someFutureMode'), StudioApplyTarget.ask);
      expect(targetOf(null), StudioApplyTarget.ask);
      expect(targetOf(42), StudioApplyTarget.ask);
    });

    test('an absent behavior object still yields ask', () {
      expect(
        StudioDesignMapper.fromJson(<String, dynamic>{})?.applyTarget ??
            StudioApplyTarget.ask,
        StudioApplyTarget.ask,
      );
    });
  });

  group('forward compatibility', () {
    test('an unknown widget kind is skipped, not fatal, and is recorded', () {
      final d = StudioDesignMapper.fromJson({
        'widgets': [
          {'kind': 'batteryRing'},
          {'kind': 'weatherOrb', 'customX': 0.5},
          {'kind': 'stepCounter'},
        ],
      })!;
      expect(d.widgets, hasLength(1));
      expect(d.widgets.single, isA<StudioBatteryRing>());
      expect(d.unsupportedWidgetKinds, ['weatherOrb', 'stepCounter']);
    });

    test('an unknown widget kind still leaves the design renderable', () {
      final d = StudioDesignMapper.fromJson({
        'clock': {'enabled': true},
        'widgets': [
          {'kind': 'somethingNew'},
        ],
      })!;
      expect(d.hasDesign, isTrue);
      expect(d.clock!.enabled, isTrue);
    });

    test('unknown top-level studio keys are ignored', () {
      final d = StudioDesignMapper.fromJson({
        'clock': {'enabled': true},
        'futureSection': {'anything': true},
        'anotherOne': [1, 2, 3],
      })!;
      expect(d.hasDesign, isTrue);
    });

    test('malformed design data never throws', () {
      final inputs = <Object?>[
        'not a map',
        42,
        <Object?>[],
        {'scene': 'broken'},
        {'widgets': 'not a list'},
        {
          'widgets': [1, 2, 'three', null],
        },
        {'dateWidget': 99},
        {'behavior': 'nope'},
        {'clock': 'nope'},
        {
          'scene': {'vignette': 'nope', 'grain': 5},
        },
      ];
      for (final input in inputs) {
        expect(
          () => StudioDesignMapper.fromJson(input),
          returnsNormally,
          reason: 'input: $input',
        );
      }
    });

    test('a malformed widget entry does not drop the valid ones', () {
      final d = StudioDesignMapper.fromJson({
        'widgets': [
          'garbage',
          {'kind': 'batteryRing'},
          null,
          {'noKind': true},
        ],
      })!;
      expect(d.widgets, hasLength(1));
    });

    test('NaN and Infinity never reach the renderers', () {
      final d = StudioDesignMapper.fromJson({
        'scene': {'brightness': double.nan, 'contrast': double.infinity},
        'widgets': [
          {'kind': 'batteryRing', 'scale': double.nan, 'customX': double.nan},
        ],
      })!;
      final ring = d.widgets.single as StudioBatteryRing;
      expect(ring.scale.isFinite, isTrue);
      expect(ring.customX, isNull);
    });
  });
}
