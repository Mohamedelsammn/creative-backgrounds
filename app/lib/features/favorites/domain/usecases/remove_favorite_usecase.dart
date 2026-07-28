import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/favorites_repository.dart';

class RemoveFavoriteUseCase implements UseCase<Unit, String> {
  RemoveFavoriteUseCase(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String wallpaperId) {
    return _repository.removeFavorite(wallpaperId);
  }
}
