import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/tw_permissions.dart';
import '../repositories/transparent_wallpaper_repository.dart';

class RequestPermissionsUseCase implements UseCase<TwPermissions, NoParams> {
  RequestPermissionsUseCase(this._repository);

  final TransparentWallpaperRepository _repository;

  @override
  Future<Either<Failure, TwPermissions>> call(NoParams params) =>
      _repository.requestPermissions();
}
