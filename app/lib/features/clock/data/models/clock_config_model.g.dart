// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClockConfigModelImpl _$$ClockConfigModelImplFromJson(
  Map<String, dynamic> json,
) => _$ClockConfigModelImpl(
  style:
      $enumDecodeNullable(_$ClockStyleEnumMap, json['style']) ??
      ClockStyle.modern,
  position:
      $enumDecodeNullable(_$ClockPositionEnumMap, json['position']) ??
      ClockPosition.center,
  font:
      $enumDecodeNullable(_$ClockFontEnumMap, json['font']) ?? ClockFont.inter,
  color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
  sizePx: (json['sizePx'] as num?)?.toDouble() ?? 76.0,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  showShadow: json['showShadow'] as bool? ?? true,
  showGlow: json['showGlow'] as bool? ?? false,
  showStroke: json['showStroke'] as bool? ?? false,
  is24Hour: json['is24Hour'] as bool? ?? false,
  showDate: json['showDate'] as bool? ?? true,
  showSeconds: json['showSeconds'] as bool? ?? false,
);

Map<String, dynamic> _$$ClockConfigModelImplToJson(
  _$ClockConfigModelImpl instance,
) => <String, dynamic>{
  'style': _$ClockStyleEnumMap[instance.style]!,
  'position': _$ClockPositionEnumMap[instance.position]!,
  'font': _$ClockFontEnumMap[instance.font]!,
  'color': instance.color,
  'sizePx': instance.sizePx,
  'opacity': instance.opacity,
  'showShadow': instance.showShadow,
  'showGlow': instance.showGlow,
  'showStroke': instance.showStroke,
  'is24Hour': instance.is24Hour,
  'showDate': instance.showDate,
  'showSeconds': instance.showSeconds,
};

const _$ClockStyleEnumMap = {
  ClockStyle.modern: 'modern',
  ClockStyle.minimal: 'minimal',
  ClockStyle.elegant: 'elegant',
  ClockStyle.digital: 'digital',
};

const _$ClockPositionEnumMap = {
  ClockPosition.top: 'top',
  ClockPosition.center: 'center',
  ClockPosition.bottom: 'bottom',
};

const _$ClockFontEnumMap = {
  ClockFont.inter: 'inter',
  ClockFont.serif: 'serif',
  ClockFont.mono: 'mono',
};
