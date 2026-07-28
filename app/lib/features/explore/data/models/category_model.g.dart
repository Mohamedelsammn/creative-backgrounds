// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryModelImpl _$$CategoryModelImplFromJson(Map<String, dynamic> json) =>
    _$CategoryModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      wallpaperCount: (json['wallpaperCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$CategoryModelImplToJson(_$CategoryModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
      'thumbnailUrl': instance.thumbnailUrl,
      'wallpaperCount': instance.wallpaperCount,
    };
