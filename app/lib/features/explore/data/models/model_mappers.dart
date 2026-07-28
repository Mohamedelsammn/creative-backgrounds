import '../../domain/entities/category_entity.dart';
import '../../domain/entities/wallpaper_entity.dart';
import 'category_model.dart';
import 'wallpaper_model.dart';

/// Entity → model mappers, used when persisting domain objects (e.g. favorites)
/// back into the model/JSON representation for storage.

String? _argbToHex(int? argb) {
  if (argb == null) return null;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#$rgb';
}

extension CategoryEntityToModel on CategoryEntity {
  CategoryModel toModel() => CategoryModel(
        id: id,
        name: name,
        color: _argbToHex(color),
        thumbnailUrl: thumbnailUrl,
        wallpaperCount: wallpaperCount,
      );
}

extension WallpaperEntityToModel on WallpaperEntity {
  WallpaperModel toModel() => WallpaperModel(
        id: id,
        title: title,
        category: category.toModel(),
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
