import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wallpaper_entity.dart';
import '../repositories/explore_repository.dart';

/// The single mixed feed (normal + depth + live, newest first) behind
/// Explore's "New Wallpapers" section.
class GetNewWallpapersUseCase
    implements UseCase<Paginated<WallpaperEntity>, PageParams> {
  GetNewWallpapersUseCase(this._repository);

  final ExploreRepository _repository;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(PageParams params) {
    return _repository.getNewWallpapers(
      cursor: params.cursor,
      forceRefresh: params.forceRefresh,
    );
  }
}
