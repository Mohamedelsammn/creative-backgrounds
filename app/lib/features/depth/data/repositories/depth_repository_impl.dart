import 'dart:convert';

import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/entities/depth_config_entity.dart';
import '../../domain/repositories/depth_repository.dart';

class DepthRepositoryImpl implements DepthRepository {
  DepthRepositoryImpl(this._storage);

  final HiveStorage _storage;

  @override
  Future<void> saveDepthConfig(DepthConfigEntity config) {
    return _storage.write(
      HiveBoxes.depthConfig,
      config.wallpaperId,
      jsonEncode({
        'enabled': config.enabled,
        'hasForegroundMask': config.hasForegroundMask,
      }),
    );
  }

  @override
  DepthConfigEntity? loadDepthConfig(String wallpaperId) {
    final raw = _storage.read<String>(HiveBoxes.depthConfig, wallpaperId);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DepthConfigEntity(
        wallpaperId: wallpaperId,
        enabled: map['enabled'] as bool? ?? false,
        hasForegroundMask: map['hasForegroundMask'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
