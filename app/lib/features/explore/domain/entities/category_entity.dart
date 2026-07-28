import 'package:equatable/equatable.dart';

/// A wallpaper category. When embedded in a wallpaper only [id]/[name]/[color]
/// are populated; the standalone `/categories` response also carries
/// [thumbnailUrl] and [wallpaperCount].
class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    this.color,
    this.thumbnailUrl,
    this.wallpaperCount,
  });

  final String id;
  final String name;

  /// ARGB color int parsed from the API hex string (e.g. "#F5A623"). Nullable —
  /// UI falls back to `AppColors.categoryAccents` by name.
  final int? color;

  final String? thumbnailUrl;
  final int? wallpaperCount;

  @override
  List<Object?> get props => [id, name, color, thumbnailUrl, wallpaperCount];
}
