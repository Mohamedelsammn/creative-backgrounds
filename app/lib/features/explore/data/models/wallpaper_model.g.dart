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
      isPremium: json['isPremium'] as bool? ?? false,
      hasForegroundMask: json['hasForegroundMask'] as bool? ?? false,
      foregroundMaskUrl: json['foregroundMaskUrl'] as String?,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
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
  'isPremium': instance.isPremium,
  'hasForegroundMask': instance.hasForegroundMask,
  'foregroundMaskUrl': instance.foregroundMaskUrl,
  'downloadCount': instance.downloadCount,
  'fileSizeBytes': instance.fileSizeBytes,
  'tags': instance.tags,
  'createdAt': instance.createdAt?.toIso8601String(),
};
