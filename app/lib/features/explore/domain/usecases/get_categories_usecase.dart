import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/explore_repository.dart';

class GetCategoriesUseCase implements UseCase<List<CategoryEntity>, NoParams> {
  GetCategoriesUseCase(this._repository);

  final ExploreRepository _repository;

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(NoParams params) {
    return _repository.getCategories();
  }
}
