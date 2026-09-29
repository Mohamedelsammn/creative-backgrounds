import 'dart:convert';

import 'package:creativebackground/features/clock/data/models/clock_config_model.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// The new Typography controls (named weight preset, horizontal scale) must
/// round-trip through `ClockConfigModel`'s JSON persistence exactly like
/// every other clock field, and stay within their documented ranges.
void main() {
  test('fontWeightPreset defaults to regular - the same weight every '
      'existing style preset already used before this control existed', () {
    const config = ClockConfigEntity();
    expect(config.fontWeightPreset, ClockWeight.regular);
  });

  test('horizontalScale defaults to 1.0 - the identity transform', () {
    const config = ClockConfigEntity();
    expect(config.horizontalScale, 1.0);
  });

  test('ClockWeight has exactly 8 named steps, extraLight through black', () {
    expect(ClockWeight.values, [
      ClockWeight.extraLight,
      ClockWeight.light,
      ClockWeight.regular,
      ClockWeight.medium,
      ClockWeight.semiBold,
      ClockWeight.bold,
      ClockWeight.extraBold,
      ClockWeight.black,
    ]);
  });

  test('fontWeightPreset and horizontalScale round-trip through '
      'ClockConfigModel fromEntity -> toJson -> fromJson -> toEntity', () {
    const original = ClockConfigEntity(
      fontWeightPreset: ClockWeight.extraBold,
      horizontalScale: 0.7,
    );

    final model = ClockConfigModel.fromEntity(original);
    final json = jsonEncode(model.toJson());
    final restored = ClockConfigModel.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    ).toEntity();

    expect(restored.fontWeightPreset, ClockWeight.extraBold);
    expect(restored.horizontalScale, 0.7);
  });

  test('a config saved before fontWeightPreset/horizontalScale existed '
      'deserializes to their identity defaults', () {
    // Simulates a pre-upgrade JSON blob - only the fields that existed
    // before this phase, nothing new.
    final legacyJson = <String, dynamic>{
      'style': 'modern',
      'position': 'center',
      'font': 'inter',
      'color': 0xFFFFFFFF,
      'sizePx': 76.0,
      'opacity': 1.0,
    };

    final restored = ClockConfigModel.fromJson(legacyJson).toEntity();

    expect(restored.fontWeightPreset, ClockWeight.regular);
    expect(restored.horizontalScale, 1.0);
    expect(restored.timeLayout, ClockTimeLayout.inline);
    expect(restored.colorMode, ClockColorMode.single);
  });

  test('changing horizontalScale leaves sizePx and stretchY untouched', () {
    const config = ClockConfigEntity(sizePx: 90, stretchY: 1.4);
    final updated = config.copyWith(horizontalScale: 0.6);

    expect(updated.sizePx, 90);
    expect(updated.stretchY, 1.4);
    expect(updated.horizontalScale, 0.6);
  });
}
