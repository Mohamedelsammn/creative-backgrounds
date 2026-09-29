import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wallpaper_entity.dart';
import '../repositories/explore_repository.dart';

class GetLiveWallpapersUseCase
    implements UseCase<Paginated<WallpaperEntity>, PageParams> {
  GetLiveWallpapersUseCase(this._repository);

  final ExploreRepository _repository;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> call(PageParams params) {
    return _repository.getLiveWallpapers(
      cursor: params.cursor,
      forceRefresh: params.forceRefresh,
    );
  }
}
