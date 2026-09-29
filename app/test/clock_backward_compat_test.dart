import 'package:creativebackground/features/clock/data/models/clock_config_model.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JSON blob saved by a build of the app from BEFORE the Depth Clock
/// Editor upgrade (12 new fields: fontWeightPreset, horizontalScale,
/// timeLayout, showColon, lineSpacing, minuteOffsetX, colorMode, hoursColor,
/// minutesColor, colonColor, colonColorCustom, strokeWidth) must still
/// deserialize cleanly and render exactly as it did before those fields
/// existed - freezed's `@Default(...)` makes every missing key fall back to
/// an identity-preserving default, never a crash or a visual change.
void main() {
  /// A realistic pre-upgrade saved config: only the fields that existed at
  /// schema version 1, a mix of user and backend-authored values.
  final legacyJson = <String, dynamic>{
    'style': 'elegant',
    'position': 'top',
    'font': 'serif',
    'color': 4294901760, // 0xFFFF0000
    'sizePx': 88.0,
    'opacity': 0.9,
    'showShadow': true,
    'showGlow': false,
    'showStroke': false,
    'is24Hour': true,
    'showDate': true,
    'showSeconds': false,
    'enabled': true,
    'remoteStyle': 'classic',
    'remoteFont': 'PlayfairDisplay',
    'weight': 300,
    'scale': 1.2,
    'rotation': 5.0,
    'depth': 0.5,
    'shadowStrength': 0.8,
    'datePosition': 'below',
    'schemaVersion': 1,
    'stretchY': 1.3,
    'dateScale': 1.1,
  };

  test('every new Depth Clock Editor field falls back to its identity '
      'default when absent from a legacy saved config', () {
    final restored = ClockConfigModel.fromJson(legacyJson).toEntity();

    expect(restored.fontWeightPreset, ClockWeight.regular);
    expect(restored.horizontalScale, 1.0);
    expect(restored.timeLayout, ClockTimeLayout.inline);
    expect(restored.showColon, isTrue);
    expect(restored.lineSpacing, 1.0);
    expect(restored.minuteOffsetX, 0.0);
    expect(restored.colorMode, ClockColorMode.single);
    expect(restored.hoursColor, isNull);
    expect(restored.minutesColor, isNull);
    expect(restored.colonColor, ClockColonColor.hours);
    expect(restored.colonColorCustom, isNull);
    expect(restored.strokeWidth, 2.0);
  });

  test('every pre-existing field survives unchanged alongside the new '
      'defaults', () {
    final restored = ClockConfigModel.fromJson(legacyJson).toEntity();

    expect(restored.style, ClockStyle.elegant);
    expect(restored.position, ClockPosition.top);
    expect(restored.font, ClockFont.serif);
    expect(restored.color, 4294901760);
    expect(restored.sizePx, 88.0);
    expect(restored.opacity, 0.9);
    expect(restored.is24Hour, isTrue);
    expect(restored.remoteStyle, 'classic');
    expect(restored.remoteFont, 'PlayfairDisplay');
    expect(restored.weight, 300);
    expect(restored.rotation, 5.0);
    expect(restored.stretchY, 1.3);
    expect(restored.dateScale, 1.1);
    expect(restored.isRemote, isTrue);
  });

  test('a legacy config restored this way equals a fresh entity built with '
      'the same original fields plus untouched new-field defaults', () {
    final restored = ClockConfigModel.fromJson(legacyJson).toEntity();

    const expected = ClockConfigEntity(
      style: ClockStyle.elegant,
      position: ClockPosition.top,
      font: ClockFont.serif,
      color: 4294901760,
      sizePx: 88.0,
      opacity: 0.9,
      is24Hour: true,
      remoteStyle: 'classic',
      remoteFont: 'PlayfairDisplay',
      weight: 300,
      scale: 1.2,
      rotation: 5.0,
      depth: 0.5,
      shadowStrength: 0.8,
      stretchY: 1.3,
      dateScale: 1.1,
    );

    expect(restored, expected);
  });

  test('an entirely empty JSON object deserializes to the plain default '
      'entity, never throwing', () {
    expect(
      () => ClockConfigModel.fromJson(<String, dynamic>{}).toEntity(),
      returnsNormally,
    );
    final restored = ClockConfigModel.fromJson(<String, dynamic>{}).toEntity();
    expect(restored, const ClockConfigEntity());
  });
}
