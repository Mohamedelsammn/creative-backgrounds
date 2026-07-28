import '../entities/clock_config_entity.dart';
import '../repositories/clock_repository.dart';

class LoadClockConfigUseCase {
  LoadClockConfigUseCase(this._repository);

  final ClockRepository _repository;

  Future<ClockConfigEntity> call() => _repository.loadClockConfig();
}
