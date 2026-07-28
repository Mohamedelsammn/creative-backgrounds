import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../entities/view_all_options.dart';

abstract class ViewAllRepository {
  /// [section] is `trending` | `latest` | `all` | a category id.
  Future<Either<Failure, Paginated<WallpaperEntity>>> getSectionWallpapers({
    required String section,
    int page = 1,
    FilterOptions? filter,
    SortOption? sort,
  });
}
