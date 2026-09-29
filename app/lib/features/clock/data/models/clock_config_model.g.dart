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
      ClockPosition.top,
  font:
      $enumDecodeNullable(_$ClockFontEnumMap, json['font']) ?? ClockFont.inter,
  color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
  sizePx: (json['sizePx'] as num?)?.toDouble() ?? 65.0,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  showShadow: json['showShadow'] as bool? ?? true,
  showGlow: json['showGlow'] as bool? ?? false,
  showStroke: json['showStroke'] as bool? ?? false,
  is24Hour: json['is24Hour'] as bool? ?? false,
  showDate: json['showDate'] as bool? ?? true,
  showSeconds: json['showSeconds'] as bool? ?? false,
  enabled: json['enabled'] as bool? ?? true,
  remoteStyle: json['remoteStyle'] as String?,
  remoteFont: json['remoteFont'] as String?,
  weight: (json['weight'] as num?)?.toInt() ?? 400,
  scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
  depth: (json['depth'] as num?)?.toDouble() ?? 0.45,
  shadowStrength: (json['shadowStrength'] as num?)?.toDouble() ?? 0.5,
  datePosition:
      $enumDecodeNullable(_$ClockDatePositionEnumMap, json['datePosition']) ??
      ClockDatePosition.below,
  dateColor: (json['dateColor'] as num?)?.toInt(),
  customX: (json['customX'] as num?)?.toDouble(),
  customY: (json['customY'] as num?)?.toDouble(),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  stretchY: (json['stretchY'] as num?)?.toDouble() ?? 1.0,
  dateScale: (json['dateScale'] as num?)?.toDouble() ?? 1.0,
  fontWeightPreset:
      $enumDecodeNullable(_$ClockWeightEnumMap, json['fontWeightPreset']) ??
      ClockWeight.regular,
  horizontalScale: (json['horizontalScale'] as num?)?.toDouble() ?? 1.0,
  timeLayout:
      $enumDecodeNullable(_$ClockTimeLayoutEnumMap, json['timeLayout']) ??
      ClockTimeLayout.inline,
  showColon: json['showColon'] as bool? ?? true,
  lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.0,
  minuteOffsetX: (json['minuteOffsetX'] as num?)?.toDouble() ?? 0.0,
  colorMode:
      $enumDecodeNullable(_$ClockColorModeEnumMap, json['colorMode']) ??
      ClockColorMode.single,
  hoursColor: (json['hoursColor'] as num?)?.toInt(),
  minutesColor: (json['minutesColor'] as num?)?.toInt(),
  colonColor:
      $enumDecodeNullable(_$ClockColonColorEnumMap, json['colonColor']) ??
      ClockColonColor.hours,
  colonColorCustom: (json['colonColorCustom'] as num?)?.toInt(),
  strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
  showAmPm: json['showAmPm'] as bool? ?? false,
  gradientFrom: (json['gradientFrom'] as num?)?.toInt(),
  gradientTo: (json['gradientTo'] as num?)?.toInt(),
  gradientAngleDeg: (json['gradientAngleDeg'] as num?)?.toDouble() ?? 180.0,
  fillOpacity: (json['fillOpacity'] as num?)?.toDouble() ?? 1.0,
  hoursFont: json['hoursFont'] as String?,
  minutesFont: json['minutesFont'] as String?,
  strokeColor: (json['strokeColor'] as num?)?.toInt() ?? 0xFF000000,
  strokeOrder:
      $enumDecodeNullable(_$ClockStrokeOrderEnumMap, json['strokeOrder']) ??
      ClockStrokeOrder.behind,
  fadeAmount: (json['fadeAmount'] as num?)?.toDouble() ?? 0.0,
  fadeDirection:
      $enumDecodeNullable(_$ClockFadeDirectionEnumMap, json['fadeDirection']) ??
      ClockFadeDirection.bottom,
  blur: (json['blur'] as num?)?.toDouble() ?? 0.0,
  hourFormat: $enumDecodeNullable(_$ClockHourFormatEnumMap, json['hourFormat']),
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
  'enabled': instance.enabled,
  'remoteStyle': instance.remoteStyle,
  'remoteFont': instance.remoteFont,
  'weight': instance.weight,
  'scale': instance.scale,
  'rotation': instance.rotation,
  'depth': instance.depth,
  'shadowStrength': instance.shadowStrength,
  'datePosition': _$ClockDatePositionEnumMap[instance.datePosition]!,
  'dateColor': instance.dateColor,
  'customX': instance.customX,
  'customY': instance.customY,
  'schemaVersion': instance.schemaVersion,
  'stretchY': instance.stretchY,
  'dateScale': instance.dateScale,
  'fontWeightPreset': _$ClockWeightEnumMap[instance.fontWeightPreset]!,
  'horizontalScale': instance.horizontalScale,
  'timeLayout': _$ClockTimeLayoutEnumMap[instance.timeLayout]!,
  'showColon': instance.showColon,
  'lineSpacing': instance.lineSpacing,
  'minuteOffsetX': instance.minuteOffsetX,
  'colorMode': _$ClockColorModeEnumMap[instance.colorMode]!,
  'hoursColor': instance.hoursColor,
  'minutesColor': instance.minutesColor,
  'colonColor': _$ClockColonColorEnumMap[instance.colonColor]!,
  'colonColorCustom': instance.colonColorCustom,
  'strokeWidth': instance.strokeWidth,
  'showAmPm': instance.showAmPm,
  'gradientFrom': instance.gradientFrom,
  'gradientTo': instance.gradientTo,
  'gradientAngleDeg': instance.gradientAngleDeg,
  'fillOpacity': instance.fillOpacity,
  'hoursFont': instance.hoursFont,
  'minutesFont': instance.minutesFont,
  'strokeColor': instance.strokeColor,
  'strokeOrder': _$ClockStrokeOrderEnumMap[instance.strokeOrder]!,
  'fadeAmount': instance.fadeAmount,
  'fadeDirection': _$ClockFadeDirectionEnumMap[instance.fadeDirection]!,
  'blur': instance.blur,
  'hourFormat': _$ClockHourFormatEnumMap[instance.hourFormat],
};

const _$ClockStyleEnumMap = {
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

const _$ClockPositionEnumMap = {
  ClockPosition.top: 'top',
  ClockPosition.center: 'center',
  ClockPosition.bottom: 'bottom',
};

const _$ClockFontEnumMap = {
  ClockFont.inter: 'inter',
  ClockFont.serif: 'serif',
  ClockFont.mono: 'mono',
  ClockFont.oswald: 'oswald',
  ClockFont.archivoBlack: 'archivoBlack',
  ClockFont.anton: 'anton',
};

const _$ClockDatePositionEnumMap = {
  ClockDatePosition.above: 'above',
  ClockDatePosition.below: 'below',
};

const _$ClockWeightEnumMap = {
  ClockWeight.extraLight: 'extraLight',
  ClockWeight.light: 'light',
  ClockWeight.regular: 'regular',
  ClockWeight.medium: 'medium',
  ClockWeight.semiBold: 'semiBold',
  ClockWeight.bold: 'bold',
  ClockWeight.extraBold: 'extraBold',
  ClockWeight.black: 'black',
};

const _$ClockTimeLayoutEnumMap = {
  ClockTimeLayout.inline: 'inline',
  ClockTimeLayout.stacked: 'stacked',
  ClockTimeLayout.stackedCompact: 'stackedCompact',
  ClockTimeLayout.offsetStack: 'offsetStack',
  ClockTimeLayout.verticalPoster: 'verticalPoster',
};

const _$ClockColorModeEnumMap = {
  ClockColorMode.single: 'single',
  ClockColorMode.split: 'split',
  ClockColorMode.gradient: 'gradient',
};

const _$ClockColonColorEnumMap = {
  ClockColonColor.hours: 'hours',
  ClockColonColor.minutes: 'minutes',
  ClockColonColor.custom: 'custom',
};

const _$ClockStrokeOrderEnumMap = {
  ClockStrokeOrder.behind: 'behind',
  ClockStrokeOrder.front: 'front',
};

const _$ClockFadeDirectionEnumMap = {
  ClockFadeDirection.bottom: 'bottom',
  ClockFadeDirection.top: 'top',
  ClockFadeDirection.both: 'both',
};

const _$ClockHourFormatEnumMap = {
  ClockHourFormat.h12: 'h12',
  ClockHourFormat.h24: 'h24',
  ClockHourFormat.auto: 'auto',
};
