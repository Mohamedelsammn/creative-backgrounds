import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/compatibility_report.dart';
import '../repositories/transparent_wallpaper_repository.dart';

class CheckCompatibilityUseCase
    implements UseCase<CompatibilityReport, NoParams> {
  CheckCompatibilityUseCase(this._repository);

  final TransparentWallpaperRepository _repository;

  @override
  Future<Either<Failure, CompatibilityReport>> call(NoParams params) =>
      _repository.checkCompatibility();
}
