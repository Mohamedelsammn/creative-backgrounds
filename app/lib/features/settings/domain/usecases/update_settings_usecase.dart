import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

enum SettingsUpdate { language, clearCache }

class UpdateSettingsUseCase implements UseCase<AppSettings, UpdateSettingsParams> {
  UpdateSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Either<Failure, AppSettings>> call(UpdateSettingsParams params) {
    switch (params.type) {
      case SettingsUpdate.language:
        return _repository.setLanguage(params.stringValue!);
      case SettingsUpdate.clearCache:
        return _repository.clearCache();
    }
  }
}

class UpdateSettingsParams extends Equatable {
  const UpdateSettingsParams(this.type, {this.stringValue, this.boolValue});

  final SettingsUpdate type;
  final String? stringValue;
  final bool? boolValue;

  @override
  List<Object?> get props => [type, stringValue, boolValue];
}
