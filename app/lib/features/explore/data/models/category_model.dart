import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/color_utils.dart';
import '../../domain/entities/category_entity.dart';

part 'category_model.freezed.dart';
part 'category_model.g.dart';

@freezed
class CategoryModel with _$CategoryModel {
  const CategoryModel._();

  const factory CategoryModel({
    required String id,
    required String name,
    @Default('') String slug,
    String? nameAr,
    String? color,
    String? thumbnailUrl,
    int? wallpaperCount,
  }) = _CategoryModel;

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);

  /// Parses a category as the public API returns it:
  /// `{ id, slug, nameEn, nameAr, iconUrl, imageUrl, color,
  /// coverThumbnailUrl, wallpaperCount }`.
  ///
  /// `imageUrl` is the CURRENT field the dashboard populates for cover art -
  /// confirmed directly against the live production
  /// `GET /api/v1/public/categories` response, where every one of the 8
  /// approved categories carries a real `imageUrl` while `coverThumbnailUrl`
  /// and `iconUrl` are both `null` for all of them. Those two are kept as
  /// fallbacks (in that order) for an older/admin response shape rather than
  /// removed outright, since the admin API previously spelled this field
  /// `iconUrl` and a public response might still spell it
  /// `coverThumbnailUrl` under some other endpoint/version.
  factory CategoryModel.fromApi(Map<String, dynamic> json) {
    final slug = json['slug'] as String? ?? '';
    return CategoryModel(
      id: json['id'] as String? ?? slug,
      name: json['nameEn'] as String? ?? json['name'] as String? ?? slug,
      slug: slug,
      nameAr: json['nameAr'] as String?,
      color: json['color'] as String?,
      thumbnailUrl: json['imageUrl'] as String? ??
          json['coverThumbnailUrl'] as String? ??
          json['iconUrl'] as String?,
      wallpaperCount: (json['wallpaperCount'] as num?)?.toInt(),
    );
  }

  CategoryEntity toEntity() => CategoryEntity(
    id: id,
    name: name,
    slug: slug,
    nameAr: nameAr,
    color: parseCssHexColorToArgb(color),
    thumbnailUrl: thumbnailUrl,
    wallpaperCount: wallpaperCount,
  );
}
