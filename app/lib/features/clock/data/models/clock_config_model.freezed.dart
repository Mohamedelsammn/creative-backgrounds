// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clock_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ClockConfigModel _$ClockConfigModelFromJson(Map<String, dynamic> json) {
  return _ClockConfigModel.fromJson(json);
}

/// @nodoc
mixin _$ClockConfigModel {
  ClockStyle get style => throw _privateConstructorUsedError;
  ClockPosition get position => throw _privateConstructorUsedError;
  ClockFont get font => throw _privateConstructorUsedError;
  int get color => throw _privateConstructorUsedError;
  double get sizePx => throw _privateConstructorUsedError;
  double get opacity => throw _privateConstructorUsedError;
  bool get showShadow => throw _privateConstructorUsedError;
  bool get showGlow => throw _privateConstructorUsedError;
  bool get showStroke => throw _privateConstructorUsedError;
  bool get is24Hour => throw _privateConstructorUsedError;
  bool get showDate => throw _privateConstructorUsedError;
  bool get showSeconds => throw _privateConstructorUsedError;

  /// Serializes this ClockConfigModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ClockConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClockConfigModelCopyWith<ClockConfigModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClockConfigModelCopyWith<$Res> {
  factory $ClockConfigModelCopyWith(
    ClockConfigModel value,
    $Res Function(ClockConfigModel) then,
  ) = _$ClockConfigModelCopyWithImpl<$Res, ClockConfigModel>;
  @useResult
  $Res call({
    ClockStyle style,
    ClockPosition position,
    ClockFont font,
    int color,
    double sizePx,
    double opacity,
    bool showShadow,
    bool showGlow,
    bool showStroke,
    bool is24Hour,
    bool showDate,
    bool showSeconds,
  });
}

/// @nodoc
class _$ClockConfigModelCopyWithImpl<$Res, $Val extends ClockConfigModel>
    implements $ClockConfigModelCopyWith<$Res> {
  _$ClockConfigModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClockConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? style = null,
    Object? position = null,
    Object? font = null,
    Object? color = null,
    Object? sizePx = null,
    Object? opacity = null,
    Object? showShadow = null,
    Object? showGlow = null,
    Object? showStroke = null,
    Object? is24Hour = null,
    Object? showDate = null,
    Object? showSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            style: null == style
                ? _value.style
                : style // ignore: cast_nullable_to_non_nullable
                      as ClockStyle,
            position: null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as ClockPosition,
            font: null == font
                ? _value.font
                : font // ignore: cast_nullable_to_non_nullable
                      as ClockFont,
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as int,
            sizePx: null == sizePx
                ? _value.sizePx
                : sizePx // ignore: cast_nullable_to_non_nullable
                      as double,
            opacity: null == opacity
                ? _value.opacity
                : opacity // ignore: cast_nullable_to_non_nullable
                      as double,
            showShadow: null == showShadow
                ? _value.showShadow
                : showShadow // ignore: cast_nullable_to_non_nullable
                      as bool,
            showGlow: null == showGlow
                ? _value.showGlow
                : showGlow // ignore: cast_nullable_to_non_nullable
                      as bool,
            showStroke: null == showStroke
                ? _value.showStroke
                : showStroke // ignore: cast_nullable_to_non_nullable
                      as bool,
            is24Hour: null == is24Hour
                ? _value.is24Hour
                : is24Hour // ignore: cast_nullable_to_non_nullable
                      as bool,
            showDate: null == showDate
                ? _value.showDate
                : showDate // ignore: cast_nullable_to_non_nullable
                      as bool,
            showSeconds: null == showSeconds
                ? _value.showSeconds
                : showSeconds // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClockConfigModelImplCopyWith<$Res>
    implements $ClockConfigModelCopyWith<$Res> {
  factory _$$ClockConfigModelImplCopyWith(
    _$ClockConfigModelImpl value,
    $Res Function(_$ClockConfigModelImpl) then,
  ) = __$$ClockConfigModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ClockStyle style,
    ClockPosition position,
    ClockFont font,
    int color,
    double sizePx,
    double opacity,
    bool showShadow,
    bool showGlow,
    bool showStroke,
    bool is24Hour,
    bool showDate,
    bool showSeconds,
  });
}

/// @nodoc
class __$$ClockConfigModelImplCopyWithImpl<$Res>
    extends _$ClockConfigModelCopyWithImpl<$Res, _$ClockConfigModelImpl>
    implements _$$ClockConfigModelImplCopyWith<$Res> {
  __$$ClockConfigModelImplCopyWithImpl(
    _$ClockConfigModelImpl _value,
    $Res Function(_$ClockConfigModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ClockConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? style = null,
    Object? position = null,
    Object? font = null,
    Object? color = null,
    Object? sizePx = null,
    Object? opacity = null,
    Object? showShadow = null,
    Object? showGlow = null,
    Object? showStroke = null,
    Object? is24Hour = null,
    Object? showDate = null,
    Object? showSeconds = null,
  }) {
    return _then(
      _$ClockConfigModelImpl(
        style: null == style
            ? _value.style
            : style // ignore: cast_nullable_to_non_nullable
                  as ClockStyle,
        position: null == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as ClockPosition,
        font: null == font
            ? _value.font
            : font // ignore: cast_nullable_to_non_nullable
                  as ClockFont,
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as int,
        sizePx: null == sizePx
            ? _value.sizePx
            : sizePx // ignore: cast_nullable_to_non_nullable
                  as double,
        opacity: null == opacity
            ? _value.opacity
            : opacity // ignore: cast_nullable_to_non_nullable
                  as double,
        showShadow: null == showShadow
            ? _value.showShadow
            : showShadow // ignore: cast_nullable_to_non_nullable
                  as bool,
        showGlow: null == showGlow
            ? _value.showGlow
            : showGlow // ignore: cast_nullable_to_non_nullable
                  as bool,
        showStroke: null == showStroke
            ? _value.showStroke
            : showStroke // ignore: cast_nullable_to_non_nullable
                  as bool,
        is24Hour: null == is24Hour
            ? _value.is24Hour
            : is24Hour // ignore: cast_nullable_to_non_nullable
                  as bool,
        showDate: null == showDate
            ? _value.showDate
            : showDate // ignore: cast_nullable_to_non_nullable
                  as bool,
        showSeconds: null == showSeconds
            ? _value.showSeconds
            : showSeconds // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ClockConfigModelImpl extends _ClockConfigModel {
  const _$ClockConfigModelImpl({
    this.style = ClockStyle.modern,
    this.position = ClockPosition.center,
    this.font = ClockFont.inter,
    this.color = 0xFFFFFFFF,
    this.sizePx = 76.0,
    this.opacity = 1.0,
    this.showShadow = true,
    this.showGlow = false,
    this.showStroke = false,
    this.is24Hour = false,
    this.showDate = true,
    this.showSeconds = false,
  }) : super._();

  factory _$ClockConfigModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClockConfigModelImplFromJson(json);

  @override
  @JsonKey()
  final ClockStyle style;
  @override
  @JsonKey()
  final ClockPosition position;
  @override
  @JsonKey()
  final ClockFont font;
  @override
  @JsonKey()
  final int color;
  @override
  @JsonKey()
  final double sizePx;
  @override
  @JsonKey()
  final double opacity;
  @override
  @JsonKey()
  final bool showShadow;
  @override
  @JsonKey()
  final bool showGlow;
  @override
  @JsonKey()
  final bool showStroke;
  @override
  @JsonKey()
  final bool is24Hour;
  @override
  @JsonKey()
  final bool showDate;
  @override
  @JsonKey()
  final bool showSeconds;

  @override
  String toString() {
    return 'ClockConfigModel(style: $style, position: $position, font: $font, color: $color, sizePx: $sizePx, opacity: $opacity, showShadow: $showShadow, showGlow: $showGlow, showStroke: $showStroke, is24Hour: $is24Hour, showDate: $showDate, showSeconds: $showSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClockConfigModelImpl &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.font, font) || other.font == font) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.sizePx, sizePx) || other.sizePx == sizePx) &&
            (identical(other.opacity, opacity) || other.opacity == opacity) &&
            (identical(other.showShadow, showShadow) ||
                other.showShadow == showShadow) &&
            (identical(other.showGlow, showGlow) ||
                other.showGlow == showGlow) &&
            (identical(other.showStroke, showStroke) ||
                other.showStroke == showStroke) &&
            (identical(other.is24Hour, is24Hour) ||
                other.is24Hour == is24Hour) &&
            (identical(other.showDate, showDate) ||
                other.showDate == showDate) &&
            (identical(other.showSeconds, showSeconds) ||
                other.showSeconds == showSeconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    style,
    position,
    font,
    color,
    sizePx,
    opacity,
    showShadow,
    showGlow,
    showStroke,
    is24Hour,
    showDate,
    showSeconds,
  );

  /// Create a copy of ClockConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClockConfigModelImplCopyWith<_$ClockConfigModelImpl> get copyWith =>
      __$$ClockConfigModelImplCopyWithImpl<_$ClockConfigModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ClockConfigModelImplToJson(this);
  }
}

abstract class _ClockConfigModel extends ClockConfigModel {
  const factory _ClockConfigModel({
    final ClockStyle style,
    final ClockPosition position,
    final ClockFont font,
    final int color,
    final double sizePx,
    final double opacity,
    final bool showShadow,
    final bool showGlow,
    final bool showStroke,
    final bool is24Hour,
    final bool showDate,
    final bool showSeconds,
  }) = _$ClockConfigModelImpl;
  const _ClockConfigModel._() : super._();

  factory _ClockConfigModel.fromJson(Map<String, dynamic> json) =
      _$ClockConfigModelImpl.fromJson;

  @override
  ClockStyle get style;
  @override
  ClockPosition get position;
  @override
  ClockFont get font;
  @override
  int get color;
  @override
  double get sizePx;
  @override
  double get opacity;
  @override
  bool get showShadow;
  @override
  bool get showGlow;
  @override
  bool get showStroke;
  @override
  bool get is24Hour;
  @override
  bool get showDate;
  @override
  bool get showSeconds;

  /// Create a copy of ClockConfigModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClockConfigModelImplCopyWith<_$ClockConfigModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
