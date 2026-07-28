import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/transparent_wallpaper_repository.dart';

class StartTransparentWallpaperUseCase implements UseCase<Unit, NoParams> {
  StartTransparentWallpaperUseCase(this._repository);

  final TransparentWallpaperRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.start();
}
