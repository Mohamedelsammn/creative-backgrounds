// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallpaper_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WallpaperModel _$WallpaperModelFromJson(Map<String, dynamic> json) {
  return _WallpaperModel.fromJson(json);
}

/// @nodoc
mixin _$WallpaperModel {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  CategoryModel get category => throw _privateConstructorUsedError;
  String get thumbnailUrl => throw _privateConstructorUsedError;
  String get fullUrl => throw _privateConstructorUsedError;
  String get resolution => throw _privateConstructorUsedError;
  bool get isPremium => throw _privateConstructorUsedError;
  bool get hasForegroundMask => throw _privateConstructorUsedError;
  String? get foregroundMaskUrl => throw _privateConstructorUsedError;
  int get downloadCount => throw _privateConstructorUsedError;
  int? get fileSizeBytes => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this WallpaperModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WallpaperModelCopyWith<WallpaperModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WallpaperModelCopyWith<$Res> {
  factory $WallpaperModelCopyWith(
    WallpaperModel value,
    $Res Function(WallpaperModel) then,
  ) = _$WallpaperModelCopyWithImpl<$Res, WallpaperModel>;
  @useResult
  $Res call({
    String id,
    String title,
    CategoryModel category,
    String thumbnailUrl,
    String fullUrl,
    String resolution,
    bool isPremium,
    bool hasForegroundMask,
    String? foregroundMaskUrl,
    int downloadCount,
    int? fileSizeBytes,
    List<String> tags,
    DateTime? createdAt,
  });

  $CategoryModelCopyWith<$Res> get category;
}

/// @nodoc
class _$WallpaperModelCopyWithImpl<$Res, $Val extends WallpaperModel>
    implements $WallpaperModelCopyWith<$Res> {
  _$WallpaperModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? category = null,
    Object? thumbnailUrl = null,
    Object? fullUrl = null,
    Object? resolution = null,
    Object? isPremium = null,
    Object? hasForegroundMask = null,
    Object? foregroundMaskUrl = freezed,
    Object? downloadCount = null,
    Object? fileSizeBytes = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as CategoryModel,
            thumbnailUrl: null == thumbnailUrl
                ? _value.thumbnailUrl
                : thumbnailUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            fullUrl: null == fullUrl
                ? _value.fullUrl
                : fullUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            resolution: null == resolution
                ? _value.resolution
                : resolution // ignore: cast_nullable_to_non_nullable
                      as String,
            isPremium: null == isPremium
                ? _value.isPremium
                : isPremium // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasForegroundMask: null == hasForegroundMask
                ? _value.hasForegroundMask
                : hasForegroundMask // ignore: cast_nullable_to_non_nullable
                      as bool,
            foregroundMaskUrl: freezed == foregroundMaskUrl
                ? _value.foregroundMaskUrl
                : foregroundMaskUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            downloadCount: null == downloadCount
                ? _value.downloadCount
                : downloadCount // ignore: cast_nullable_to_non_nullable
                      as int,
            fileSizeBytes: freezed == fileSizeBytes
                ? _value.fileSizeBytes
                : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                      as int?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategoryModelCopyWith<$Res> get category {
    return $CategoryModelCopyWith<$Res>(_value.category, (value) {
      return _then(_value.copyWith(category: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WallpaperModelImplCopyWith<$Res>
    implements $WallpaperModelCopyWith<$Res> {
  factory _$$WallpaperModelImplCopyWith(
    _$WallpaperModelImpl value,
    $Res Function(_$WallpaperModelImpl) then,
  ) = __$$WallpaperModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    CategoryModel category,
    String thumbnailUrl,
    String fullUrl,
    String resolution,
    bool isPremium,
    bool hasForegroundMask,
    String? foregroundMaskUrl,
    int downloadCount,
    int? fileSizeBytes,
    List<String> tags,
    DateTime? createdAt,
  });

  @override
  $CategoryModelCopyWith<$Res> get category;
}

/// @nodoc
class __$$WallpaperModelImplCopyWithImpl<$Res>
    extends _$WallpaperModelCopyWithImpl<$Res, _$WallpaperModelImpl>
    implements _$$WallpaperModelImplCopyWith<$Res> {
  __$$WallpaperModelImplCopyWithImpl(
    _$WallpaperModelImpl _value,
    $Res Function(_$WallpaperModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? category = null,
    Object? thumbnailUrl = null,
    Object? fullUrl = null,
    Object? resolution = null,
    Object? isPremium = null,
    Object? hasForegroundMask = null,
    Object? foregroundMaskUrl = freezed,
    Object? downloadCount = null,
    Object? fileSizeBytes = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$WallpaperModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as CategoryModel,
        thumbnailUrl: null == thumbnailUrl
            ? _value.thumbnailUrl
            : thumbnailUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        fullUrl: null == fullUrl
            ? _value.fullUrl
            : fullUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        resolution: null == resolution
            ? _value.resolution
            : resolution // ignore: cast_nullable_to_non_nullable
                  as String,
        isPremium: null == isPremium
            ? _value.isPremium
            : isPremium // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasForegroundMask: null == hasForegroundMask
            ? _value.hasForegroundMask
            : hasForegroundMask // ignore: cast_nullable_to_non_nullable
                  as bool,
        foregroundMaskUrl: freezed == foregroundMaskUrl
            ? _value.foregroundMaskUrl
            : foregroundMaskUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        downloadCount: null == downloadCount
            ? _value.downloadCount
            : downloadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        fileSizeBytes: freezed == fileSizeBytes
            ? _value.fileSizeBytes
            : fileSizeBytes // ignore: cast_nullable_to_non_nullable
                  as int?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WallpaperModelImpl extends _WallpaperModel {
  const _$WallpaperModelImpl({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.resolution,
    this.isPremium = false,
    this.hasForegroundMask = false,
    this.foregroundMaskUrl,
    this.downloadCount = 0,
    this.fileSizeBytes,
    final List<String> tags = const <String>[],
    this.createdAt,
  }) : _tags = tags,
       super._();

  factory _$WallpaperModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$WallpaperModelImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final CategoryModel category;
  @override
  final String thumbnailUrl;
  @override
  final String fullUrl;
  @override
  final String resolution;
  @override
  @JsonKey()
  final bool isPremium;
  @override
  @JsonKey()
  final bool hasForegroundMask;
  @override
  final String? foregroundMaskUrl;
  @override
  @JsonKey()
  final int downloadCount;
  @override
  final int? fileSizeBytes;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'WallpaperModel(id: $id, title: $title, category: $category, thumbnailUrl: $thumbnailUrl, fullUrl: $fullUrl, resolution: $resolution, isPremium: $isPremium, hasForegroundMask: $hasForegroundMask, foregroundMaskUrl: $foregroundMaskUrl, downloadCount: $downloadCount, fileSizeBytes: $fileSizeBytes, tags: $tags, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WallpaperModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.fullUrl, fullUrl) || other.fullUrl == fullUrl) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.isPremium, isPremium) ||
                other.isPremium == isPremium) &&
            (identical(other.hasForegroundMask, hasForegroundMask) ||
                other.hasForegroundMask == hasForegroundMask) &&
            (identical(other.foregroundMaskUrl, foregroundMaskUrl) ||
                other.foregroundMaskUrl == foregroundMaskUrl) &&
            (identical(other.downloadCount, downloadCount) ||
                other.downloadCount == downloadCount) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    category,
    thumbnailUrl,
    fullUrl,
    resolution,
    isPremium,
    hasForegroundMask,
    foregroundMaskUrl,
    downloadCount,
    fileSizeBytes,
    const DeepCollectionEquality().hash(_tags),
    createdAt,
  );

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WallpaperModelImplCopyWith<_$WallpaperModelImpl> get copyWith =>
      __$$WallpaperModelImplCopyWithImpl<_$WallpaperModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WallpaperModelImplToJson(this);
  }
}

abstract class _WallpaperModel extends WallpaperModel {
  const factory _WallpaperModel({
    required final String id,
    required final String title,
    required final CategoryModel category,
    required final String thumbnailUrl,
    required final String fullUrl,
    required final String resolution,
    final bool isPremium,
    final bool hasForegroundMask,
    final String? foregroundMaskUrl,
    final int downloadCount,
    final int? fileSizeBytes,
    final List<String> tags,
    final DateTime? createdAt,
  }) = _$WallpaperModelImpl;
  const _WallpaperModel._() : super._();

  factory _WallpaperModel.fromJson(Map<String, dynamic> json) =
      _$WallpaperModelImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  CategoryModel get category;
  @override
  String get thumbnailUrl;
  @override
  String get fullUrl;
  @override
  String get resolution;
  @override
  bool get isPremium;
  @override
  bool get hasForegroundMask;
  @override
  String? get foregroundMaskUrl;
  @override
  int get downloadCount;
  @override
  int? get fileSizeBytes;
  @override
  List<String> get tags;
  @override
  DateTime? get createdAt;

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WallpaperModelImplCopyWith<_$WallpaperModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
