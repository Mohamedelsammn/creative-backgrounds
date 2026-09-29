import '../../../clock/data/models/remote_clock_config_mapper.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_assets.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'category_model.dart';
import 'wallpaper_model.dart';

/// Entity -> model mappers, used when persisting domain objects (e.g.
/// favorites) back into the model/JSON representation for storage.
///
/// These must round-trip everything `WallpaperModel.toEntity()` produced,
/// otherwise favoriting a depth or video wallpaper would quietly downgrade it
/// to a flat image the next time it is read back.

String? _argbToHex(int? argb) {
  if (argb == null) return null;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#$rgb';
}

extension CategoryEntityToModel on CategoryEntity {
  CategoryModel toModel() => CategoryModel(
    id: id,
    name: name,
    slug: slug,
    nameAr: nameAr,
    color: _argbToHex(color),
    thumbnailUrl: thumbnailUrl,
    wallpaperCount: wallpaperCount,
  );
}

extension WallpaperEntityToModel on WallpaperEntity {
  WallpaperModel toModel() => WallpaperModel(
    id: id,
    slug: slug,
    title: title,
    description: description,
    type: type.wire,
    category: category.toModel(),
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
    clockConfig: remoteClockConfig == null
        ? null
        : RemoteClockConfigMapper.toJson(remoteClockConfig!),
    depthConfig: _depthToJson(depthRenderConfig),
    video: _videoToJson(video),
    assets: _assetsToJson(assets),
    dominantColor: _argbToHex(dominantColor),
    blurhash: blurhash,
    downloadCount: downloadCount,
    fileSizeBytes: fileSizeBytes,
    tags: tags,
    createdAt: createdAt,
    isDetailed: isDetailed,
  );
}

Map<String, dynamic>? _depthToJson(DepthRenderConfig? config) {
  if (config == null) return null;
  return {
    'foregroundScale': config.foregroundScale,
    'foregroundOffsetX': config.foregroundOffsetX,
    'foregroundOffsetY': config.foregroundOffsetY,
    'blurRadius': config.blurRadius,
    'shadowStrength': config.shadowStrength,
  };
}

Map<String, dynamic>? _videoToJson(VideoAsset? video) {
  if (video == null) return null;
  return {
    'url': video.url,
    'mime': video.mime,
    'width': video.width,
    'height': video.height,
    'durationMs': video.durationMs,
    'fps': video.fps,
    'sizeBytes': video.sizeBytes,
    'codec': video.codec,
  };
}

Map<String, dynamic>? _assetsToJson(Map<String, RemoteAsset> assets) {
  if (assets.isEmpty) return null;
  return assets.map(
    (kind, asset) => MapEntry(kind, {
      'url': asset.url,
      'mime': asset.mime,
      'width': asset.width,
      'height': asset.height,
      'bytes': asset.bytes,
    }),
  );
}
