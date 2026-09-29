// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallpaper_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WallpaperModelImpl _$$WallpaperModelImplFromJson(Map<String, dynamic> json) =>
    _$WallpaperModelImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      category: CategoryModel.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      thumbnailUrl: json['thumbnailUrl'] as String,
      fullUrl: json['fullUrl'] as String,
      resolution: json['resolution'] as String,
      type: json['type'] as String? ?? 'standard',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      hasForegroundMask: json['hasForegroundMask'] as bool? ?? false,
      foregroundMaskUrl: json['foregroundMaskUrl'] as String?,
      backgroundUrl: json['backgroundUrl'] as String?,
      clockConfig: json['clockConfig'] as Map<String, dynamic>?,
      depthConfig: json['depthConfig'] as Map<String, dynamic>?,
      studio: json['studio'] as Map<String, dynamic>?,
      video: json['video'] as Map<String, dynamic>?,
      assets: json['assets'] as Map<String, dynamic>?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      dominantColor: json['dominantColor'] as String?,
      blurhash: json['blurhash'] as String?,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      isDetailed: json['isDetailed'] as bool? ?? false,
    );

Map<String, dynamic> _$$WallpaperModelImplToJson(
  _$WallpaperModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'category': instance.category,
  'thumbnailUrl': instance.thumbnailUrl,
  'fullUrl': instance.fullUrl,
  'resolution': instance.resolution,
  'type': instance.type,
  'slug': instance.slug,
  'description': instance.description,
  'isPremium': instance.isPremium,
  'isFeatured': instance.isFeatured,
  'hasForegroundMask': instance.hasForegroundMask,
  'foregroundMaskUrl': instance.foregroundMaskUrl,
  'backgroundUrl': instance.backgroundUrl,
  'clockConfig': instance.clockConfig,
  'depthConfig': instance.depthConfig,
  'studio': instance.studio,
  'video': instance.video,
  'assets': instance.assets,
  'width': instance.width,
  'height': instance.height,
  'dominantColor': instance.dominantColor,
  'blurhash': instance.blurhash,
  'downloadCount': instance.downloadCount,
  'fileSizeBytes': instance.fileSizeBytes,
  'tags': instance.tags,
  'createdAt': instance.createdAt?.toIso8601String(),
  'isDetailed': instance.isDetailed,
};
