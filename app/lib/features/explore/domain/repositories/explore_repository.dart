import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../entities/category_entity.dart';
import '../entities/wallpaper_entity.dart';

/// Explore data contract. Implemented in the data layer with Hive caching in
/// front of the remote datasource.
abstract class ExploreRepository {
  Future<Either<Failure, Paginated<WallpaperEntity>>> getTrending({int page = 1});

  Future<Either<Failure, Paginated<WallpaperEntity>>> getLatest({int page = 1});

  Future<Either<Failure, List<CategoryEntity>>> getCategories();
}
