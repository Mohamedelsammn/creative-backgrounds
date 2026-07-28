import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../repositories/wallpaper_details_repository.dart';

class GetWallpaperDetailsUseCase implements UseCase<WallpaperEntity, String> {
  GetWallpaperDetailsUseCase(this._repository);

  final WallpaperDetailsRepository _repository;

  @override
  Future<Either<Failure, WallpaperEntity>> call(String id) {
    return _repository.getWallpaperDetails(id);
  }
}
