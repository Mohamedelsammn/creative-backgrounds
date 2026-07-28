import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/wallpaper_entity.dart';
import 'category_model.dart';

part 'wallpaper_model.freezed.dart';
part 'wallpaper_model.g.dart';

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
    @Default(false) bool isPremium,
    @Default(false) bool hasForegroundMask,
    String? foregroundMaskUrl,
    @Default(0) int downloadCount,
    int? fileSizeBytes,
    @Default(<String>[]) List<String> tags,
    DateTime? createdAt,
  }) = _WallpaperModel;

  factory WallpaperModel.fromJson(Map<String, dynamic> json) =>
      _$WallpaperModelFromJson(json);

  WallpaperEntity toEntity() => WallpaperEntity(
        id: id,
        title: title,
        category: category.toEntity(),
        thumbnailUrl: thumbnailUrl,
        fullUrl: fullUrl,
        resolution: resolution,
        isPremium: isPremium,
        hasForegroundMask: hasForegroundMask,
        foregroundMaskUrl: foregroundMaskUrl,
        downloadCount: downloadCount,
        fileSizeBytes: fileSizeBytes,
        tags: tags,
        createdAt: createdAt,
      );
}
