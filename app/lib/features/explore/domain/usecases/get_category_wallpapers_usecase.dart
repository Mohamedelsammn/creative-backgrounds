import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wallpaper_entity.dart';
import '../repositories/explore_repository.dart';

class GetCategoryWallpapersUseCase
    implements UseCase<Paginated<WallpaperEntity>, CategoryWallpapersParams> {
  GetCategoryWallpapersUseCase(this._repository);

  final ExploreRepository _repository;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(
    CategoryWallpapersParams params,
  ) {
    return _repository.getCategoryWallpapers(
      categorySlug: params.categorySlug,
      cursor: params.cursor,
      forceRefresh: params.forceRefresh,
    );
  }
}

class CategoryWallpapersParams extends Equatable {
  const CategoryWallpapersParams({
    required this.categorySlug,
    this.cursor,
    this.forceRefresh = false,
  });

  final String categorySlug;
  final String? cursor;
  final bool forceRefresh;

  @override
  List<Object?> get props => [categorySlug, cursor, forceRefresh];
}
