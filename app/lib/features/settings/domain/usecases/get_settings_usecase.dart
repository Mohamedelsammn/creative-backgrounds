import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class GetSettingsUseCase implements UseCase<AppSettings, NoParams> {
  GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Either<Failure, AppSettings>> call(NoParams params) =>
      _repository.getSettings();
}
