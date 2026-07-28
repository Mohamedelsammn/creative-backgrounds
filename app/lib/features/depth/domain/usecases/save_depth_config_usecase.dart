import '../entities/depth_config_entity.dart';
import '../repositories/depth_repository.dart';

class SaveDepthConfigUseCase {
  SaveDepthConfigUseCase(this._repository);

  final DepthRepository _repository;

  Future<void> call(DepthConfigEntity config) =>
      _repository.saveDepthConfig(config);
}
