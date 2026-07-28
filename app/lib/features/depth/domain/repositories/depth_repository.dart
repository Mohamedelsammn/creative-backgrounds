import '../entities/depth_config_entity.dart';

abstract class DepthRepository {
  Future<void> saveDepthConfig(DepthConfigEntity config);
  DepthConfigEntity? loadDepthConfig(String wallpaperId);
}
