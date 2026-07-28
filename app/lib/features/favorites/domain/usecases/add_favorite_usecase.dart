import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../repositories/favorites_repository.dart';

class AddFavoriteUseCase implements UseCase<Unit, WallpaperEntity> {
  AddFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(WallpaperEntity params) {
    return _repository.addFavorite(params);
  }
}
