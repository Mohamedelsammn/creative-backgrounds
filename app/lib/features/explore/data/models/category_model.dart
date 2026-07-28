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
    String? color,
    String? thumbnailUrl,
    int? wallpaperCount,
  }) = _CategoryModel;

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);

  CategoryEntity toEntity() => CategoryEntity(
        id: id,
        name: name,
        color: parseHexColorToArgb(color),
        thumbnailUrl: thumbnailUrl,
        wallpaperCount: wallpaperCount,
      );
}
