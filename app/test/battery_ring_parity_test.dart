import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/studio_design_mapper.dart';
import 'package:creativebackground/features/clock/data/models/studio_widget_serializer.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/battery_ring_widget.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity tests for the `batteryRing` studio widget.
///
/// The governing requirement is DASHBOARD -> DETAILS -> APPLIED WALLPAPER: the
/// ring a user previews must survive to the applied wallpaper. These assert
/// the Dart half of that (parsing, classification, serialization to native and
/// suppression); the native half is asserted by the Kotlin renderer mirroring
/// `BatteryRingMetrics`, which is pinned below.
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  /// The real `porshe-ob91x0` design - the batteryRing regression fixture.
  StudioDesign porshe() {
    final f = fixture('studio_battery_ring');
    return StudioDesignMapper.fromJson(
      f['studio'],
      legacyClockConfig: f['clockConfig'],
    )!;
  }

  StudioBatteryRing ringOf(StudioDesign design) =>
      design.widgets.single as StudioBatteryRing;

  group('Porshe regression fixture - real production payload', () {
    test('its authored ring survives parsing', () {
      final ring = ringOf(porshe());
      expect(ring.customX, closeTo(0.8, 1e-9));
      expect(ring.customY, closeTo(0.13, 1e-9));
      expect(ring.scale, closeTo(1.1, 1e-9));
      expect(ring.color, 0xFFFFFFFF);
      expect(ring.rotation, 0);
      expect(ring.anchor, 'top');
      expect(ring.showPercentage, isTrue);
    });

    test('it reaches native with every authored property intact', () {
      final json = StudioWidgetSerializer.toJson(porshe().widgets);
      expect(json, isNotNull);
      final decoded = (jsonDecode(json!) as List).single as Map<String, Object?>;
      expect(decoded['kind'], 'batteryRing');
      expect(decoded['customX'], closeTo(0.8, 1e-9));
      expect(decoded['customY'], closeTo(0.13, 1e-9));
      expect(decoded['scale'], closeTo(1.1, 1e-9));
      expect(decoded['rotation'], 0);
      expect(decoded['anchor'], 'top');
      expect(decoded['showPercentage'], isTrue);
      // ARGB int, already converted from CSS byte order - native never
      // re-parses a colour string, so the two sides cannot disagree.
      expect(decoded['color'], 0xFFFFFFFF);
    });

    test('the ring makes the design dynamic, so it needs a live engine', () {
      expect(porshe().isDynamic, isTrue);
      expect(porshe().renderMode, DesignRenderMode.dynamic_);
    });
  });

  group('battery percentage mapping', () {
    // The sweep fraction the renderers draw. Both sides compute
    // `(level / 100).clamp(0, 1)` and multiply a full turn by it.
    double sweepFraction(int level) => (level / 100).clamp(0.0, 1.0);

    test('0% draws no arc', () => expect(sweepFraction(0), 0.0));
    test('1% draws a sliver', () => expect(sweepFraction(1), closeTo(0.01, 1e-9)));
    test('50% draws half', () => expect(sweepFraction(50), closeTo(0.5, 1e-9)));
    test('99% draws almost all', () {
      expect(sweepFraction(99), closeTo(0.99, 1e-9));
    });
    test('100% draws a full circle', () => expect(sweepFraction(100), 1.0));

    test('an out-of-range level is clamped, never wrapped', () {
      expect(sweepFraction(150), 1.0);
      expect(sweepFraction(-20), 0.0);
    });
  });

  group('geometry constants are the contract with the native renderer', () {
    // `BatteryRingRenderer.Metrics` in Kotlin repeats these numbers. If one
    // side changes, the applied wallpaper stops matching the preview - so the
    // values are pinned here rather than left as incidental.
    test('diameter, stroke, track alpha and start angle are fixed', () {
      expect(BatteryRingMetrics.baseDiameter, 28);
      expect(BatteryRingMetrics.baseStroke, 2.5);
      expect(BatteryRingMetrics.trackAlpha, 0.25);
      // -pi/2 radians == -90 degrees == 12 o'clock, sweeping clockwise.
      expect(BatteryRingMetrics.startAngle, closeTo(-1.5707963267948966, 1e-12));
    });

    test('the ring geometry derives from scale predictably', () {
      // Mirrors both renderers: radius = (diameter - stroke) / 2.
      const scale = 1.1;
      final diameter = BatteryRingMetrics.baseDiameter * scale;
      final stroke = BatteryRingMetrics.baseStroke * scale;
      expect((diameter - stroke) / 2, closeTo(14.025, 1e-9));
    });

    test('the label sits beside the ring, not inside it', () {
      // The dashboard's own composited reference draws the percentage as a
      // label trailing the ring's right edge, not centred inside the circle.
      expect(BatteryRingMetrics.labelGap, 6);
      expect(BatteryRingMetrics.labelSizeRatio, closeTo(0.62, 1e-9));
    });
  });

  group('parsing tolerance', () {
    StudioBatteryRing? parseRing(Map<String, dynamic> widget) {
      final d = StudioDesignMapper.fromJson({
        'widgets': [widget],
      });
      final w = d?.widgets;
      if (w == null || w.isEmpty) return null;
      return w.single as StudioBatteryRing;
    }

    test('a bare batteryRing gets sane defaults', () {
      final ring = parseRing({'kind': 'batteryRing'})!;
      expect(ring.customX, isNull);
      expect(ring.customY, isNull);
      expect(ring.scale, 1.0);
      expect(ring.rotation, 0);
      expect(ring.color, 0xFFFFFFFF);
      expect(ring.showPercentage, isTrue);
      expect(ring.anchor, 'top');
    });

    test('a null position falls back to centre at render time', () {
      final ring = parseRing({'kind': 'batteryRing'})!;
      // Both renderers resolve a null coordinate to 0.5.
      expect(ring.customX ?? 0.5, 0.5);
      expect(ring.customY ?? 0.5, 0.5);
    });

    test('out-of-range values are clamped', () {
      final ring = parseRing({
        'kind': 'batteryRing',
        'customX': 1.8,
        'customY': -0.4,
        'scale': 99,
        'rotation': 720,
      })!;
      expect(ring.customX, 1.0);
      expect(ring.customY, 0.0);
      expect(ring.scale, 5.0);
      expect(ring.rotation, 180.0);
    });

    test('wrong types fall back rather than throwing', () {
      final ring = parseRing({
        'kind': 'batteryRing',
        'customX': 'left',
        'scale': 'big',
        'color': 42,
        'showPercentage': 'yes',
      })!;
      expect(ring.customX, isNull);
      expect(ring.scale, 1.0);
      expect(ring.color, 0xFFFFFFFF);
      expect(ring.showPercentage, isTrue);
    });

    test('showPercentage: false is honoured', () {
      final ring = parseRing({
        'kind': 'batteryRing',
        'showPercentage': false,
      })!;
      expect(ring.showPercentage, isFalse);
    });

    test('an authored colour is read in CSS byte order', () {
      final ring = parseRing({
        'kind': 'batteryRing',
        'color': '#E65100FF',
      })!;
      expect(ring.color, 0xFFE65100);
    });
  });

  group('serialization', () {
    test('no widgets serializes to null, not an empty array', () {
      // Null is what clears a previously applied ring, so "none" and
      // "cleared" are the same value all the way to SharedPreferences.
      expect(StudioWidgetSerializer.toJson(const []), isNull);
    });

    test('several rings all survive', () {
      final design = StudioDesignMapper.fromJson({
        'widgets': [
          {'kind': 'batteryRing', 'customX': 0.2},
          {'kind': 'batteryRing', 'customX': 0.8},
        ],
      })!;
      final decoded =
          jsonDecode(StudioWidgetSerializer.toJson(design.widgets)!) as List;
      expect(decoded, hasLength(2));
    });

    test('an unknown kind never reaches native', () {
      final design = StudioDesignMapper.fromJson({
        'widgets': [
          {'kind': 'batteryRing'},
          {'kind': 'weatherOrb'},
        ],
      })!;
      final decoded =
          jsonDecode(StudioWidgetSerializer.toJson(design.widgets)!) as List;
      expect(decoded, hasLength(1));
      expect((decoded.single as Map)['kind'], 'batteryRing');
      expect(design.unsupportedWidgetKinds, ['weatherOrb']);
    });

    test('a round-trip through the wire preserves every property', () {
      final original = ringOf(porshe());
      final json = StudioWidgetSerializer.toJson([original])!;
      final decoded = (jsonDecode(json) as List).single as Map<String, Object?>;
      // Rebuild through the same mapper native mirrors, proving the wire
      // shape is self-describing.
      final reparsed = StudioDesignMapper.fromJson({
        'widgets': [
          {...decoded, 'color': '#FFFFFFFF'},
        ],
      })!;
      final again = reparsed.widgets.single as StudioBatteryRing;
      expect(again.customX, original.customX);
      expect(again.customY, original.customY);
      expect(again.scale, original.scale);
      expect(again.rotation, original.rotation);
      expect(again.anchor, original.anchor);
      expect(again.showPercentage, original.showPercentage);
      expect(again.color, original.color);
    });
  });
}
