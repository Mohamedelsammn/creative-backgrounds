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

  /// The backend's `type` string (`standard` / `depth` / `video`).
  String get type => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  bool get isPremium => throw _privateConstructorUsedError;
  bool get isFeatured => throw _privateConstructorUsedError;
  bool get hasForegroundMask => throw _privateConstructorUsedError;
  String? get foregroundMaskUrl => throw _privateConstructorUsedError;
  String? get backgroundUrl => throw _privateConstructorUsedError;

  /// Backend `clockConfig`, stored exactly as received.
  Map<String, dynamic>? get clockConfig => throw _privateConstructorUsedError;

  /// Backend `depthConfig`, stored exactly as received.
  Map<String, dynamic>? get depthConfig => throw _privateConstructorUsedError;

  /// Backend `studio` (the current design generation), stored exactly as
  /// received. May coexist with [clockConfig]; see [StudioDesignMapper] for
  /// which one supplies the clock.
  Map<String, dynamic>? get studio => throw _privateConstructorUsedError;

  /// Backend `video`, stored exactly as received.
  Map<String, dynamic>? get video => throw _privateConstructorUsedError;

  /// Detail-only `assets` map, keyed by asset kind.
  Map<String, dynamic>? get assets => throw _privateConstructorUsedError;
  int get width => throw _privateConstructorUsedError;
  int get height => throw _privateConstructorUsedError;
  String? get dominantColor => throw _privateConstructorUsedError;
  String? get blurhash => throw _privateConstructorUsedError;
  int get downloadCount => throw _privateConstructorUsedError;
  int? get fileSizeBytes => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  bool get isDetailed => throw _privateConstructorUsedError;

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
    String type,
    String slug,
    String? description,
    bool isPremium,
    bool isFeatured,
    bool hasForegroundMask,
    String? foregroundMaskUrl,
    String? backgroundUrl,
    Map<String, dynamic>? clockConfig,
    Map<String, dynamic>? depthConfig,
    Map<String, dynamic>? studio,
    Map<String, dynamic>? video,
    Map<String, dynamic>? assets,
    int width,
    int height,
    String? dominantColor,
    String? blurhash,
    int downloadCount,
    int? fileSizeBytes,
    List<String> tags,
    DateTime? createdAt,
    bool isDetailed,
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
    Object? type = null,
    Object? slug = null,
    Object? description = freezed,
    Object? isPremium = null,
    Object? isFeatured = null,
    Object? hasForegroundMask = null,
    Object? foregroundMaskUrl = freezed,
    Object? backgroundUrl = freezed,
    Object? clockConfig = freezed,
    Object? depthConfig = freezed,
    Object? studio = freezed,
    Object? video = freezed,
    Object? assets = freezed,
    Object? width = null,
    Object? height = null,
    Object? dominantColor = freezed,
    Object? blurhash = freezed,
    Object? downloadCount = null,
    Object? fileSizeBytes = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
    Object? isDetailed = null,
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
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            isPremium: null == isPremium
                ? _value.isPremium
                : isPremium // ignore: cast_nullable_to_non_nullable
                      as bool,
            isFeatured: null == isFeatured
                ? _value.isFeatured
                : isFeatured // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasForegroundMask: null == hasForegroundMask
                ? _value.hasForegroundMask
                : hasForegroundMask // ignore: cast_nullable_to_non_nullable
                      as bool,
            foregroundMaskUrl: freezed == foregroundMaskUrl
                ? _value.foregroundMaskUrl
                : foregroundMaskUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            backgroundUrl: freezed == backgroundUrl
                ? _value.backgroundUrl
                : backgroundUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            clockConfig: freezed == clockConfig
                ? _value.clockConfig
                : clockConfig // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            depthConfig: freezed == depthConfig
                ? _value.depthConfig
                : depthConfig // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            studio: freezed == studio
                ? _value.studio
                : studio // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            video: freezed == video
                ? _value.video
                : video // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            assets: freezed == assets
                ? _value.assets
                : assets // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            width: null == width
                ? _value.width
                : width // ignore: cast_nullable_to_non_nullable
                      as int,
            height: null == height
                ? _value.height
                : height // ignore: cast_nullable_to_non_nullable
                      as int,
            dominantColor: freezed == dominantColor
                ? _value.dominantColor
                : dominantColor // ignore: cast_nullable_to_non_nullable
                      as String?,
            blurhash: freezed == blurhash
                ? _value.blurhash
                : blurhash // ignore: cast_nullable_to_non_nullable
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
            isDetailed: null == isDetailed
                ? _value.isDetailed
                : isDetailed // ignore: cast_nullable_to_non_nullable
                      as bool,
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
    String type,
    String slug,
    String? description,
    bool isPremium,
    bool isFeatured,
    bool hasForegroundMask,
    String? foregroundMaskUrl,
    String? backgroundUrl,
    Map<String, dynamic>? clockConfig,
    Map<String, dynamic>? depthConfig,
    Map<String, dynamic>? studio,
    Map<String, dynamic>? video,
    Map<String, dynamic>? assets,
    int width,
    int height,
    String? dominantColor,
    String? blurhash,
    int downloadCount,
    int? fileSizeBytes,
    List<String> tags,
    DateTime? createdAt,
    bool isDetailed,
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
    Object? type = null,
    Object? slug = null,
    Object? description = freezed,
    Object? isPremium = null,
    Object? isFeatured = null,
    Object? hasForegroundMask = null,
    Object? foregroundMaskUrl = freezed,
    Object? backgroundUrl = freezed,
    Object? clockConfig = freezed,
    Object? depthConfig = freezed,
    Object? studio = freezed,
    Object? video = freezed,
    Object? assets = freezed,
    Object? width = null,
    Object? height = null,
    Object? dominantColor = freezed,
    Object? blurhash = freezed,
    Object? downloadCount = null,
    Object? fileSizeBytes = freezed,
    Object? tags = null,
    Object? createdAt = freezed,
    Object? isDetailed = null,
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
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        isPremium: null == isPremium
            ? _value.isPremium
            : isPremium // ignore: cast_nullable_to_non_nullable
                  as bool,
        isFeatured: null == isFeatured
            ? _value.isFeatured
            : isFeatured // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasForegroundMask: null == hasForegroundMask
            ? _value.hasForegroundMask
            : hasForegroundMask // ignore: cast_nullable_to_non_nullable
                  as bool,
        foregroundMaskUrl: freezed == foregroundMaskUrl
            ? _value.foregroundMaskUrl
            : foregroundMaskUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        backgroundUrl: freezed == backgroundUrl
            ? _value.backgroundUrl
            : backgroundUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        clockConfig: freezed == clockConfig
            ? _value._clockConfig
            : clockConfig // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        depthConfig: freezed == depthConfig
            ? _value._depthConfig
            : depthConfig // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        studio: freezed == studio
            ? _value._studio
            : studio // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        video: freezed == video
            ? _value._video
            : video // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        assets: freezed == assets
            ? _value._assets
            : assets // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
        dominantColor: freezed == dominantColor
            ? _value.dominantColor
            : dominantColor // ignore: cast_nullable_to_non_nullable
                  as String?,
        blurhash: freezed == blurhash
            ? _value.blurhash
            : blurhash // ignore: cast_nullable_to_non_nullable
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
        isDetailed: null == isDetailed
            ? _value.isDetailed
            : isDetailed // ignore: cast_nullable_to_non_nullable
                  as bool,
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
    this.type = 'standard',
    this.slug = '',
    this.description,
    this.isPremium = false,
    this.isFeatured = false,
    this.hasForegroundMask = false,
    this.foregroundMaskUrl,
    this.backgroundUrl,
    final Map<String, dynamic>? clockConfig,
    final Map<String, dynamic>? depthConfig,
    final Map<String, dynamic>? studio,
    final Map<String, dynamic>? video,
    final Map<String, dynamic>? assets,
    this.width = 0,
    this.height = 0,
    this.dominantColor,
    this.blurhash,
    this.downloadCount = 0,
    this.fileSizeBytes,
    final List<String> tags = const <String>[],
    this.createdAt,
    this.isDetailed = false,
  }) : _clockConfig = clockConfig,
       _depthConfig = depthConfig,
       _studio = studio,
       _video = video,
       _assets = assets,
       _tags = tags,
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

  /// The backend's `type` string (`standard` / `depth` / `video`).
  @override
  @JsonKey()
  final String type;
  @override
  @JsonKey()
  final String slug;
  @override
  final String? description;
  @override
  @JsonKey()
  final bool isPremium;
  @override
  @JsonKey()
  final bool isFeatured;
  @override
  @JsonKey()
  final bool hasForegroundMask;
  @override
  final String? foregroundMaskUrl;
  @override
  final String? backgroundUrl;

  /// Backend `clockConfig`, stored exactly as received.
  final Map<String, dynamic>? _clockConfig;

  /// Backend `clockConfig`, stored exactly as received.
  @override
  Map<String, dynamic>? get clockConfig {
    final value = _clockConfig;
    if (value == null) return null;
    if (_clockConfig is EqualUnmodifiableMapView) return _clockConfig;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Backend `depthConfig`, stored exactly as received.
  final Map<String, dynamic>? _depthConfig;

  /// Backend `depthConfig`, stored exactly as received.
  @override
  Map<String, dynamic>? get depthConfig {
    final value = _depthConfig;
    if (value == null) return null;
    if (_depthConfig is EqualUnmodifiableMapView) return _depthConfig;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Backend `studio` (the current design generation), stored exactly as
  /// received. May coexist with [clockConfig]; see [StudioDesignMapper] for
  /// which one supplies the clock.
  final Map<String, dynamic>? _studio;

  /// Backend `studio` (the current design generation), stored exactly as
  /// received. May coexist with [clockConfig]; see [StudioDesignMapper] for
  /// which one supplies the clock.
  @override
  Map<String, dynamic>? get studio {
    final value = _studio;
    if (value == null) return null;
    if (_studio is EqualUnmodifiableMapView) return _studio;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Backend `video`, stored exactly as received.
  final Map<String, dynamic>? _video;

  /// Backend `video`, stored exactly as received.
  @override
  Map<String, dynamic>? get video {
    final value = _video;
    if (value == null) return null;
    if (_video is EqualUnmodifiableMapView) return _video;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Detail-only `assets` map, keyed by asset kind.
  final Map<String, dynamic>? _assets;

  /// Detail-only `assets` map, keyed by asset kind.
  @override
  Map<String, dynamic>? get assets {
    final value = _assets;
    if (value == null) return null;
    if (_assets is EqualUnmodifiableMapView) return _assets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final int width;
  @override
  @JsonKey()
  final int height;
  @override
  final String? dominantColor;
  @override
  final String? blurhash;
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
  @JsonKey()
  final bool isDetailed;

  @override
  String toString() {
    return 'WallpaperModel(id: $id, title: $title, category: $category, thumbnailUrl: $thumbnailUrl, fullUrl: $fullUrl, resolution: $resolution, type: $type, slug: $slug, description: $description, isPremium: $isPremium, isFeatured: $isFeatured, hasForegroundMask: $hasForegroundMask, foregroundMaskUrl: $foregroundMaskUrl, backgroundUrl: $backgroundUrl, clockConfig: $clockConfig, depthConfig: $depthConfig, studio: $studio, video: $video, assets: $assets, width: $width, height: $height, dominantColor: $dominantColor, blurhash: $blurhash, downloadCount: $downloadCount, fileSizeBytes: $fileSizeBytes, tags: $tags, createdAt: $createdAt, isDetailed: $isDetailed)';
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
            (identical(other.type, type) || other.type == type) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.isPremium, isPremium) ||
                other.isPremium == isPremium) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.hasForegroundMask, hasForegroundMask) ||
                other.hasForegroundMask == hasForegroundMask) &&
            (identical(other.foregroundMaskUrl, foregroundMaskUrl) ||
                other.foregroundMaskUrl == foregroundMaskUrl) &&
            (identical(other.backgroundUrl, backgroundUrl) ||
                other.backgroundUrl == backgroundUrl) &&
            const DeepCollectionEquality().equals(
              other._clockConfig,
              _clockConfig,
            ) &&
            const DeepCollectionEquality().equals(
              other._depthConfig,
              _depthConfig,
            ) &&
            const DeepCollectionEquality().equals(other._studio, _studio) &&
            const DeepCollectionEquality().equals(other._video, _video) &&
            const DeepCollectionEquality().equals(other._assets, _assets) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.dominantColor, dominantColor) ||
                other.dominantColor == dominantColor) &&
            (identical(other.blurhash, blurhash) ||
                other.blurhash == blurhash) &&
            (identical(other.downloadCount, downloadCount) ||
                other.downloadCount == downloadCount) &&
            (identical(other.fileSizeBytes, fileSizeBytes) ||
                other.fileSizeBytes == fileSizeBytes) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isDetailed, isDetailed) ||
                other.isDetailed == isDetailed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    category,
    thumbnailUrl,
    fullUrl,
    resolution,
    type,
    slug,
    description,
    isPremium,
    isFeatured,
    hasForegroundMask,
    foregroundMaskUrl,
    backgroundUrl,
    const DeepCollectionEquality().hash(_clockConfig),
    const DeepCollectionEquality().hash(_depthConfig),
    const DeepCollectionEquality().hash(_studio),
    const DeepCollectionEquality().hash(_video),
    const DeepCollectionEquality().hash(_assets),
    width,
    height,
    dominantColor,
    blurhash,
    downloadCount,
    fileSizeBytes,
    const DeepCollectionEquality().hash(_tags),
    createdAt,
    isDetailed,
  ]);

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
    final String type,
    final String slug,
    final String? description,
    final bool isPremium,
    final bool isFeatured,
    final bool hasForegroundMask,
    final String? foregroundMaskUrl,
    final String? backgroundUrl,
    final Map<String, dynamic>? clockConfig,
    final Map<String, dynamic>? depthConfig,
    final Map<String, dynamic>? studio,
    final Map<String, dynamic>? video,
    final Map<String, dynamic>? assets,
    final int width,
    final int height,
    final String? dominantColor,
    final String? blurhash,
    final int downloadCount,
    final int? fileSizeBytes,
    final List<String> tags,
    final DateTime? createdAt,
    final bool isDetailed,
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

  /// The backend's `type` string (`standard` / `depth` / `video`).
  @override
  String get type;
  @override
  String get slug;
  @override
  String? get description;
  @override
  bool get isPremium;
  @override
  bool get isFeatured;
  @override
  bool get hasForegroundMask;
  @override
  String? get foregroundMaskUrl;
  @override
  String? get backgroundUrl;

  /// Backend `clockConfig`, stored exactly as received.
  @override
  Map<String, dynamic>? get clockConfig;

  /// Backend `depthConfig`, stored exactly as received.
  @override
  Map<String, dynamic>? get depthConfig;

  /// Backend `studio` (the current design generation), stored exactly as
  /// received. May coexist with [clockConfig]; see [StudioDesignMapper] for
  /// which one supplies the clock.
  @override
  Map<String, dynamic>? get studio;

  /// Backend `video`, stored exactly as received.
  @override
  Map<String, dynamic>? get video;

  /// Detail-only `assets` map, keyed by asset kind.
  @override
  Map<String, dynamic>? get assets;
  @override
  int get width;
  @override
  int get height;
  @override
  String? get dominantColor;
  @override
  String? get blurhash;
  @override
  int get downloadCount;
  @override
  int? get fileSizeBytes;
  @override
  List<String> get tags;
  @override
  DateTime? get createdAt;
  @override
  bool get isDetailed;

  /// Create a copy of WallpaperModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WallpaperModelImplCopyWith<_$WallpaperModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
