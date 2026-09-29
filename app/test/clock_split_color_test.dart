import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Split hour/minute coloring (`ClockColorMode.split`) is a config/entity
/// level feature consumed identically by `ClockPainter` and `ClockRenderer.kt`
/// - both split the formatted time string around its first ":" and color the
/// hour/colon/minute segments independently. These tests cover the shared
/// entity contract both renderers rely on: defaults, null-color fallback, and
/// the colon color's "default to hours" rule.
void main() {
  test('colorMode defaults to single - identical to every config that '
      'existed before split colors', () {
    const config = ClockConfigEntity();
    expect(config.colorMode, ClockColorMode.single);
    expect(config.hoursColor, isNull);
    expect(config.minutesColor, isNull);
  });

  test('colonColor defaults to hours - turning on split mode never requires '
      'a fourth decision before it looks right', () {
    const config = ClockConfigEntity();
    expect(config.colonColor, ClockColonColor.hours);
  });

  test('switching to split mode with no explicit hours/minutes color set '
      'falls back to the base color for both, never rendering transparent '
      'or black text', () {
    const config = ClockConfigEntity(
      colorMode: ClockColorMode.split,
      color: 0xFF00FF00,
    );
    expect(config.hoursColor ?? config.color, 0xFF00FF00);
    expect(config.minutesColor ?? config.color, 0xFF00FF00);
  });

  test('explicit hours/minutes colors override the base color independently',
      () {
    const config = ClockConfigEntity(
      colorMode: ClockColorMode.split,
      color: 0xFFFFFFFF,
      hoursColor: 0xFFFFFFFF,
      minutesColor: 0xFFFF8800,
    );
    expect(config.hoursColor, 0xFFFFFFFF);
    expect(config.minutesColor, 0xFFFF8800);
    expect(config.hoursColor, isNot(config.minutesColor));
  });

  test('colonColorCustom is only meaningful when colonColor is custom, and '
      'is null by default', () {
    const config = ClockConfigEntity();
    expect(config.colonColorCustom, isNull);

    const customColon = ClockConfigEntity(
      colonColor: ClockColonColor.custom,
      colonColorCustom: 0xFF123456,
    );
    expect(customColon.colonColor, ClockColonColor.custom);
    expect(customColon.colonColorCustom, 0xFF123456);
  });

  test('two configs differing only in colorMode are not equal', () {
    const single = ClockConfigEntity();
    const split = ClockConfigEntity(colorMode: ClockColorMode.split);
    expect(single, isNot(split));
  });

  test('copyWith changes only the split-color fields, leaving the rest of '
      'the config untouched', () {
    const config = ClockConfigEntity(sizePx: 90, rotation: 15);
    final updated = config.copyWith(
      colorMode: ClockColorMode.split,
      hoursColor: 0xFFFFFFFF,
      minutesColor: 0xFF000000,
    );
    expect(updated.sizePx, 90);
    expect(updated.rotation, 15);
    expect(updated.colorMode, ClockColorMode.split);
  });
}
