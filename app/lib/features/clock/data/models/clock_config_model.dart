import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/clock_config_entity.dart';

part 'clock_config_model.freezed.dart';
part 'clock_config_model.g.dart';

@freezed
class ClockConfigModel with _$ClockConfigModel {
  const ClockConfigModel._();

  const factory ClockConfigModel({
    @Default(ClockStyle.modern) ClockStyle style,
    @Default(ClockPosition.center) ClockPosition position,
    @Default(ClockFont.inter) ClockFont font,
    @Default(0xFFFFFFFF) int color,
    @Default(76.0) double sizePx,
    @Default(1.0) double opacity,
    @Default(true) bool showShadow,
    @Default(false) bool showGlow,
    @Default(false) bool showStroke,
    @Default(false) bool is24Hour,
    @Default(true) bool showDate,
    @Default(false) bool showSeconds,
  }) = _ClockConfigModel;

  factory ClockConfigModel.fromJson(Map<String, dynamic> json) =>
      _$ClockConfigModelFromJson(json);

  factory ClockConfigModel.fromEntity(ClockConfigEntity e) => ClockConfigModel(
        style: e.style,
        position: e.position,
        font: e.font,
        color: e.color,
        sizePx: e.sizePx,
        opacity: e.opacity,
        showShadow: e.showShadow,
        showGlow: e.showGlow,
        showStroke: e.showStroke,
        is24Hour: e.is24Hour,
        showDate: e.showDate,
        showSeconds: e.showSeconds,
      );

  ClockConfigEntity toEntity() => ClockConfigEntity(
        style: style,
        position: position,
        font: font,
        color: color,
        sizePx: sizePx,
        opacity: opacity,
        showShadow: showShadow,
        showGlow: showGlow,
        showStroke: showStroke,
        is24Hour: is24Hour,
        showDate: showDate,
        showSeconds: showSeconds,
      );
}
