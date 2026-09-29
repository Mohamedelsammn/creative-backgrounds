import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../clock/data/models/studio_design_mapper.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_assets.dart';
import '../../domain/entities/wallpaper_entity.dart';
import '../../domain/entities/wallpaper_type.dart';
import 'category_model.dart';

part 'wallpaper_model.freezed.dart';
part 'wallpaper_model.g.dart';

/// Data-layer wallpaper.
///
/// The backend's nested objects ([clockConfig], [depthConfig], [video],
/// [assets]) are held **verbatim** as maps rather than exploded into fields.
/// That keeps one parse path for both the wire and the Hive cache, means a
/// field the content team authors is never dropped on a cache round-trip, and
/// leaves all interpretation to the mappers where it belongs.
@freezed
class WallpaperModel with _$WallpaperModel {
  const WallpaperModel._();

  const factory WallpaperModel({
    required String id,
    required String title,
    required CategoryModel category,
    required String thumbnailUrl,
    required String fullUrl,
    required String resolution,

    /// The backend's `type` string (`standard` / `depth` / `video`).
    @Default('standard') String type,
    @Default('') String slug,
    String? description,
    @Default(false) bool isPremium,
    @Default(false) bool isFeatured,
    @Default(false) bool hasForegroundMask,
    String? foregroundMaskUrl,
    String? backgroundUrl,

    /// Backend `clockConfig`, stored exactly as received.
    Map<String, dynamic>? clockConfig,

    /// Backend `depthConfig`, stored exactly as received.
    Map<String, dynamic>? depthConfig,

    /// Backend `studio` (the current design generation), stored exactly as
    /// received. May coexist with [clockConfig]; see [StudioDesignMapper] for
    /// which one supplies the clock.
    Map<String, dynamic>? studio,

    /// Backend `video`, stored exactly as received.
    Map<String, dynamic>? video,

    /// Detail-only `assets` map, keyed by asset kind.
    Map<String, dynamic>? assets,
    @Default(0) int width,
    @Default(0) int height,
    String? dominantColor,
    String? blurhash,
    @Default(0) int downloadCount,
    int? fileSizeBytes,
    @Default(<String>[]) List<String> tags,
    DateTime? createdAt,
    @Default(false) bool isDetailed,
  }) = _WallpaperModel;

  factory WallpaperModel.fromJson(Map<String, dynamic> json) =>
      _$WallpaperModelFromJson(json);

  /// Parses a **feed / search / related** row from the public API.
  ///
  /// These rows are deliberately light: they always carry `thumbnailUrl` but
  /// only carry `background` / `foreground` / `clockConfig` / `depthConfig`
  /// when the request asked for `include=depth`. [fullUrl] therefore falls back
  /// to the thumbnail here and is upgraded by [WallpaperModel.fromApiDetail].
  ///
  /// [resolveCategory] turns the row's `categorySlug` into a full category;
  /// when it returns null a placeholder is synthesized from the slug so the UI
  /// always has a name to show.
  factory WallpaperModel.fromApiFeedItem(
    Map<String, dynamic> json, {
    CategoryModel? Function(String slug)? resolveCategory,
  }) {
    final slug = json['categorySlug'] as String? ?? '';
    final thumbnail = json['thumbnailUrl'] as String? ?? '';
    final background = json['background'] as String?;
    final foreground = json['foreground'] as String?;

    return WallpaperModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'standard',
      category: _category(slug, resolveCategory),
      thumbnailUrl: thumbnail,
      // A list row deliberately has NO full-resolution URL: pointing [fullUrl]
      // at a real asset here would let any list widget that reaches for it
      // pull a multi-megabyte image while merely drawing a card. The detail
      // response upgrades it. The depth background is still carried separately
      // for the compositing preview, which only runs on the details screen.
      fullUrl: thumbnail,
      backgroundUrl: background,
      foregroundMaskUrl: foreground,
      hasForegroundMask: foreground?.isNotEmpty ?? false,
      resolution: json['resolutionLabel'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      clockConfig: _map(json['clockConfig']),
      depthConfig: _map(json['depthConfig']),
      studio: _map(json['studio']),
      video: _map(json['video']),
      dominantColor: json['dominantColor'] as String?,
      blurhash: json['blurhash'] as String?,
      downloadCount: (json['downloads'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      tags: _tags(json['tags']),
      createdAt: _date(json['publishedAt']),
      isDetailed: false,
    );
  }

  /// Parses the **detail** response, which differs from a feed row in several
  /// ways: the thumbnail is `thumbnail` (not `thumbnailUrl`), the category is a
  /// nested object rather than a slug, `assets` lists every stored file, and
  /// there is no `downloads` / `fileSizeBytes` / `blurhash`.
  ///
  /// [previous] is the list row this detail was opened from, if any. Its
  /// download count and file size are carried over so the info panel does not
  /// blank out numbers the list already showed.
  factory WallpaperModel.fromApiDetail(
    Map<String, dynamic> json, {
    WallpaperModel? previous,
  }) {
    final assets = _map(json['assets']) ?? const {};
    final thumbnail =
        json['thumbnail'] as String? ??
        _assetUrl(assets, AssetKind.thumbnail) ??
        previous?.thumbnailUrl ??
        '';
    final background =
        json['background'] as String? ??
        _assetUrl(assets, AssetKind.background);
    final foreground =
        json['foreground'] as String? ??
        _assetUrl(assets, AssetKind.foreground);
    final wireType = json['type'] as String? ?? previous?.type ?? 'standard';
    final isDepth = WallpaperType.fromWire(wireType) == WallpaperType.depth;

    // The wallpaper-sized image, in descending order of fidelity.
    //
    // For a DEPTH wallpaper the authored look is background + subject + clock
    // composited together - this backend does not publish a flattened
    // full-resolution render of that composite (no ORIGINAL asset is stored
    // for depth type; only THUMBNAIL/BACKGROUND/FOREGROUND). The `background`
    // plate alone is missing the subject and the clock, so it must never be
    // shown as "the wallpaper" on its own - that was the original bug: Details
    // rendered an empty scene. `thumbnail` is the one asset the backend does
    // render as the full composed image (see the dashboard's Thumbnail
    // Generator step), so it is the best available stand-in for an original
    // until a full-resolution flattened asset exists.
    //
    // ORIGINAL, when present, is preferred for every type: it is explicitly
    // the uncut authored source. For a non-depth wallpaper the background
    // plate IS the whole image, so it remains the right fallback there.
    final full =
        _assetUrl(assets, AssetKind.original) ??
        (isDepth
            ? (thumbnail.isNotEmpty ? thumbnail : background)
            : background) ??
        _assetUrl(assets, AssetKind.preview) ??
        thumbnail;

    final categoryJson = json['category'];
    final category = categoryJson is Map
        ? CategoryModel.fromApi(Map<String, dynamic>.from(categoryJson))
        : (previous?.category ?? const CategoryModel(id: '', name: ''));

    return WallpaperModel(
      id: json['id'] as String? ?? previous?.id ?? '',
      slug: json['slug'] as String? ?? previous?.slug ?? '',
      title: json['title'] as String? ?? previous?.title ?? '',
      description: json['description'] as String?,
      type: wireType,
      category: category,
      thumbnailUrl: thumbnail,
      fullUrl: full,
      backgroundUrl: background,
      foregroundMaskUrl: foreground,
      hasForegroundMask: foreground?.isNotEmpty ?? false,
      resolution:
          json['resolutionLabel'] as String? ?? previous?.resolution ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      clockConfig: _map(json['clockConfig']) ?? previous?.clockConfig,
      depthConfig: _map(json['depthConfig']) ?? previous?.depthConfig,
      studio: _map(json['studio']) ?? previous?.studio,
      video: _map(json['video']) ?? previous?.video,
      assets: assets.isEmpty ? null : assets,
      dominantColor:
          json['dominantColor'] as String? ?? previous?.dominantColor,
      // Absent from the detail contract - keep whatever the list already knew.
      blurhash: previous?.blurhash,
      downloadCount: previous?.downloadCount ?? 0,
      fileSizeBytes: previous?.fileSizeBytes ?? _assetBytes(assets),
      tags: _tags(json['tags']),
      createdAt: _date(json['publishedAt']) ?? previous?.createdAt,
      isDetailed: true,
    );
  }

  WallpaperEntity toEntity() {
    final wallpaperType = WallpaperType.fromWire(type);
    // One canonical design per wallpaper, whichever generation authored it.
    // `studio.clock` wins over the legacy top-level `clockConfig`; a
    // wallpaper can carry `studio` with a null clock and still have a legacy
    // one, so both containers are handed over rather than assumed exclusive.
    final design = StudioDesignMapper.fromJson(
      studio,
      legacyClockConfig: clockConfig,
    );
    final clock = design?.clock;
    return WallpaperEntity(
      id: id,
      slug: slug,
      title: title,
      description: description,
      category: category.toEntity(),
      type: wallpaperType,
      thumbnailUrl: thumbnailUrl,
      fullUrl: fullUrl,
      backgroundUrl: backgroundUrl,
      foregroundMaskUrl: foregroundMaskUrl,
      hasForegroundMask: hasForegroundMask,
      resolution: resolution,
      width: width,
      height: height,
      isPremium: isPremium,
      isFeatured: isFeatured,
      remoteClockConfig: clock,
      design: design,
      depthRenderConfig: _depthRenderConfig(depthConfig),
      video: _videoAsset(video),
      assets: _assetEntities(assets),
      dominantColor: parseCssHexColorToArgb(dominantColor),
      blurhash: blurhash,
      downloadCount: downloadCount,
      fileSizeBytes: fileSizeBytes,
      tags: tags,
      createdAt: createdAt,
      isDetailed: isDetailed,
    );
  }

  // --- parsing helpers ---------------------------------------------------

  static CategoryModel _category(
    String slug,
    CategoryModel? Function(String slug)? resolve,
  ) {
    final resolved = resolve?.call(slug);
    if (resolved != null) return resolved;
    final entity = CategoryEntity.fromSlug(slug);
    return CategoryModel(id: entity.id, name: entity.name, slug: entity.slug);
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  /// The API sends tags as `[{slug, name}]`; the app only shows names. Plain
  /// string arrays are also accepted so cached and fixture data round-trip.
  static List<String> _tags(Object? value) {
    if (value is! List) return const [];
    final out = <String>[];
    for (final tag in value) {
      if (tag is String) {
        out.add(tag);
      } else if (tag is Map) {
        final name = tag['name'] ?? tag['slug'];
        if (name is String && name.isNotEmpty) out.add(name);
      }
    }
    return out;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _assetUrl(Map<String, dynamic> assets, String kind) {
    final asset = assets[kind];
    if (asset is! Map) return null;
    final url = asset['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  /// Size of the asset a user would actually download, for the info panel.
  static int? _assetBytes(Map<String, dynamic> assets) {
    for (final kind in [AssetKind.original, AssetKind.videoLoop]) {
      final asset = assets[kind];
      if (asset is Map && asset['bytes'] is num) {
        return (asset['bytes'] as num).toInt();
      }
    }
    return null;
  }

  static Map<String, RemoteAsset> _assetEntities(Map<String, dynamic>? assets) {
    if (assets == null || assets.isEmpty) return const {};
    final out = <String, RemoteAsset>{};
    assets.forEach((kind, value) {
      if (value is! Map) return;
      final url = value['url'];
      if (url is! String || url.isEmpty) return;
      out[kind] = RemoteAsset(
        url: url,
        mime: value['mime'] as String? ?? '',
        width: (value['width'] as num?)?.toInt(),
        height: (value['height'] as num?)?.toInt(),
        bytes: (value['bytes'] as num?)?.toInt() ?? 0,
      );
    });
    return out;
  }

  static DepthRenderConfig? _depthRenderConfig(Map<String, dynamic>? json) {
    if (json == null) return null;
    double read(String key, double fallback, double min, double max) {
      final value = json[key];
      return value is num ? value.toDouble().clamp(min, max) : fallback;
    }

    return DepthRenderConfig(
      foregroundScale: read('foregroundScale', 1.0, 0.5, 3.0),
      foregroundOffsetX: read('foregroundOffsetX', 0, -1, 1),
      foregroundOffsetY: read('foregroundOffsetY', 0, -1, 1),
      blurRadius: read('blurRadius', 0, 0, 100),
      shadowStrength: read('shadowStrength', 0, 0, 1),
    );
  }

  static VideoAsset? _videoAsset(Map<String, dynamic>? json) {
    if (json == null) return null;
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    return VideoAsset(
      url: url,
      mime: json['mime'] as String? ?? 'video/mp4',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      fps: (json['fps'] as num?)?.toDouble() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      codec: json['codec'] as String? ?? '',
    );
  }
}
