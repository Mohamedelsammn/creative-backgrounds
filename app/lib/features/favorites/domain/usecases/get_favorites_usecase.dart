import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../repositories/favorites_repository.dart';

class GetFavoritesUseCase implements UseCase<List<WallpaperEntity>, NoParams> {
  GetFavoritesUseCase(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, List<WallpaperEntity>>> call(NoParams params) {
    return _repository.getFavorites();
  }
}
