import 'package:creativebackground/features/clock/data/models/clock_config_model.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the vertical-stretch field end-to-end at the model layer: default
/// value, independence from uniform size, and persistence round-trip. The
/// actual canvas transform lives in `ClockPainter`/`ClockRenderer.kt` and is
/// not covered here - there is no existing golden/widget-rendering harness in
/// this project to extend, and inventing one for a single field would be a
/// disproportionate footprint for this change.
void main() {
  group('ClockConfigEntity.stretchY', () {
    test('defaults to 1.0 - the identity transform', () {
      const config = ClockConfigEntity();
      expect(config.stretchY, 1.0);
      expect(config.isStretched, isFalse);
    });

    test('copyWith changes only stretchY, leaving sizePx untouched', () {
      const original = ClockConfigEntity(sizePx: 76);
      final stretched = original.copyWith(stretchY: 2.0);

      expect(stretched.stretchY, 2.0);
      expect(stretched.sizePx, 76, reason: 'stretch must not affect size');
      expect(stretched.isStretched, isTrue);
    });

    test('changing sizePx does not reset an existing stretch', () {
      const original = ClockConfigEntity(stretchY: 1.8);
      final resized = original.copyWith(sizePx: 200);

      expect(resized.stretchY, 1.8, reason: 'size must not affect stretch');
      expect(resized.sizePx, 200);
    });

    test('position and rotation are independent of stretch', () {
      const config = ClockConfigEntity(
        stretchY: 2.5,
        position: ClockPosition.bottom,
        rotation: 15,
        remoteStyle: 'bold', // isRemote gate, so rotation actually renders
      );
      final stretched = config.copyWith(stretchY: 1.0);

      expect(stretched.position, ClockPosition.bottom);
      expect(stretched.rotation, 15);
    });

    test('two configs differing only in stretchY are not equal', () {
      const a = ClockConfigEntity(stretchY: 1.0);
      const b = ClockConfigEntity(stretchY: 1.5);
      expect(a, isNot(equals(b)));
    });
  });

  group('ClockConfigModel <-> entity round-trip', () {
    test('stretchY survives fromEntity -> toJson -> fromJson -> toEntity',
        () {
      const original = ClockConfigEntity(stretchY: 2.3, sizePx: 150);

      final json = ClockConfigModel.fromEntity(original).toJson();
      final restored = ClockConfigModel.fromJson(json).toEntity();

      expect(restored.stretchY, 2.3);
      expect(restored.sizePx, 150);
    });

    test('a config saved before this field existed defaults to no stretch',
        () {
      // Simulates a JSON blob written by an older build of the app, which has
      // never heard of `stretchY`.
      final legacyJson = ClockConfigModel.fromEntity(
        const ClockConfigEntity(sizePx: 90),
      ).toJson()
        ..remove('stretchY');

      final restored = ClockConfigModel.fromJson(legacyJson).toEntity();
      expect(restored.stretchY, 1.0);
      expect(restored.isStretched, isFalse);
    });
  });
}
