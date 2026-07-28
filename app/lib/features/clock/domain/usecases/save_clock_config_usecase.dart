import '../entities/clock_config_entity.dart';
import '../repositories/clock_repository.dart';

class SaveClockConfigUseCase {
  SaveClockConfigUseCase(this._repository);

  final ClockRepository _repository;

  Future<void> call(ClockConfigEntity config) =>
      _repository.saveClockConfig(config);
}
